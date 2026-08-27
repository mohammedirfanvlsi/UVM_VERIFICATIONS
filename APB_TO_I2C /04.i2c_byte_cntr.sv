// ========================================================================
// Module Name: i2c_byte_cntr (I2C Byte-Level Controller)
// Description:
//   This module handles parallel-to-serial serialization (for Writes) and
//   serial-to-parallel deserialization (for Reads) of 8-bit bytes.
//   It coordinates byte-level protocol steps by sending bit-level commands
//   to the Bit Controller.
// ========================================================================


module i2c_byte_cntr (
        input  wire        clk,        // System Clock (PCLK)
        input  wire        rst_n,      // Active-low asynchronous reset
        input  wire [7:0]  din,        // 8-bit data coming from the APB TX Register (txr)
        input  wire        ack_in,     // Acknowledge bit received from the slave (NACK=1, ACK=0)
        input  wire        start,      // Command bit from APB Control Register (Generate START)
        input  wire        write,      // Command bit from APB Control Register (Generate WRITE)
        input  wire        read,       // Command bit from APB Control Register (Generate READ)
        input  wire        stop,       // Command bit from APB Control Register (Generate STOP)

        output reg  [7:0]  dout,       // 8-bit data received from Slave, sent back to APB RX Register (rxr)
        output reg         cmd_ack,    // Goes High for 1 cycle to tell APB: "I finished your command!"
        output reg         ack_out,    // Acknowledge bit to send TO the slave during a Master Read
        output reg         i2c_busy,   // Status flag indicating the I2C bus is currently active

        output reg  [3:0]  bit_cmd,    // 4-bit command sent DOWN to the Bit Controller (START, WRITE, READ, STOP)
        output wire        bit_din,    // 1-bit data sent DOWN to the Bit Controller (The actual 0 or 1 to transmit)
        input  wire        bit_ack,    // Feedback from Bit Controller: "I finished sending 1 bit!"
        input  wire        bit_dout    // 1-bit data read FROM the I2C bus by the Bit Controller
    );

        // FSM State Encodings
        localparam state_idle  = 3'd0; // Waiting for APB commands
        localparam state_start = 3'd1; // Telling Bit Controller to generate START
        localparam state_data  = 3'd2; // Shifting 8 bits of data in/out
        localparam state_ack   = 3'd3; // The 9th bit (Handling the ACK)
        localparam state_stop  = 3'd4; // Telling Bit Controller to generate STOP
        localparam state_done  = 3'd5; // Cleaning up and alerting APB

        reg [2:0] state;               // Current state of the FSM
        reg [2:0] bit_counter;         // Counts from 7 down to 0 for the 8 bits of data
        reg [7:0] shift_reg;           // Holds the 8 bits being shifted out to the bus

        // =========================================================================
        // THE COMBINATORIAL DATA FIX:
        // By using a 'wire' and 'assign', we physically force the bit_din wire to
        // INSTANTLY equal the 7th bit of our shift register the exact microsecond
        // we enter the write state. This prevents 1-clock-cycle delays that used to
        // cause the MSB to be transmitted incorrectly.
        // =========================================================================
        assign bit_din = (state == state_data && write) ? shift_reg[7] :
                         (state == state_ack && !write) ? ack_in : 1'b0;

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                // On reset, clear all registers to safe default values
                state       <= state_idle;
                dout        <= 8'h00;
                bit_cmd     <= 4'b0000;
                ack_out     <= 1'b0;
                cmd_ack     <= 1'b0;
                i2c_busy    <= 1'b0;
                bit_counter <= 3'd0;
                shift_reg   <= 8'h00;
            end else begin
                // By default, only pulse cmd_ack for exactly 1 clock cycle.
                // It will be forced back to 0 immediately unless explicitly set to 1.
                cmd_ack <= 1'b0;

                case(state)
                    state_idle : begin
                        // If CPU gave us any command AND we aren't currently asserting an ACK
                        if((start || write || read || stop) && !cmd_ack) begin
                            i2c_busy  <= 1'b1;         // Lock the bus
                            shift_reg <= din;          // Load the 8 bits from APB into our shift register

                            if (start) begin
                                state   <= state_start;
                                bit_cmd <= 4'b0001;    // Tell Bit Controller: Generate START
                            end else begin
                                state       <= state_data;
                                bit_counter <= 3'd7;   // Start counting from bit 7 (MSB first)
                                if(write) begin
                                    bit_cmd <= 4'b0100; // Tell Bit Controller: Generate WRITE
                                end else begin
                                    bit_cmd <= 4'b1000; // Tell Bit Controller: Generate READ
                                end
                            end
                        end else begin
                            // If no command, rest in idle
                            i2c_busy <= 1'b0;
                            bit_cmd  <= 4'b0000;
                        end
                    end

                    state_start : begin
                        // Wait until Bit Controller says "START bit is done!"
                        if(bit_ack) begin
                            state       <= state_data;
                            bit_counter <= 3'd7;         // Prepare to send 8 bits
                            if(write) begin
                                bit_cmd <= 4'b0100;      // Move to WRITE mode
                            end else begin
                                bit_cmd <= 4'b1000;      // Move to READ mode
                            end
                        end
                    end

                    state_data : begin
                        // Wait for the Bit Controller to finish sending/reading 1 single bit
                        if(bit_ack) begin
                            if(read) begin
                                // If reading: shift left and pull the new bit from the I2C wire into the LSB (Bit 0)
                                shift_reg <= (shift_reg << 1) | bit_dout;
                            end else begin
                                // If writing: just shift left. (The MSB falls off, and Bit 6 becomes the new Bit 7)
                                shift_reg <= shift_reg << 1;
                            end

                            // Check if we just finished the last bit (bit_counter hit 0)
                            if (bit_counter == 3'd0) begin
                                state <= state_ack;     // Move to the 9th bit (ACK phase)
                                if(write) begin
                                    bit_cmd <= 4'b1000; // If we wrote data, we must READ the slave's ACK
                                end else begin
                                    bit_cmd <= 4'b0100; // If we read data, we must WRITE our own ACK to the slave
                                end
                            end else begin
                                // We are not done with the 8 bits yet.
                                bit_counter <= bit_counter - 3'd1; // Decrement counter (e.g., 7 becomes 6)

                                // Keep telling the Bit Controller to execute data bits
                                if(write) begin
                                    bit_cmd <= 4'b0100;
                                end else begin
                                    bit_cmd <= 4'b1000;
                                end
                            end
                        end
                    end

                    state_ack : begin
                        // Wait for the 9th bit (ACK) to finish physically transmitting
                        if(bit_ack) begin
                            if(write) ack_out <= bit_dout; // If we were writing, capture the Slave's ACK to send to APB
                            if(read)  dout <= shift_reg;   // If we were reading, our 8-bit shift register is full. Save it to dout!

                            // After the ACK, do we stop or do we just finish the burst?
                            if(stop) begin
                                state   <= state_stop;
                                bit_cmd <= 4'b0010;  // Tell Bit Controller: Generate STOP
                            end else begin
                                state   <= state_done; // Go alert the CPU we finished the byte
                            end
                        end
                    end

                    state_stop : begin
                        // Wait for the physical STOP condition to finish
                        if(bit_ack) state <= state_done;
                    end

                    state_done : begin
                        cmd_ack <= 1'b1;        // Pulse High: "Hey CPU, the byte is fully finished!"
                        bit_cmd <= 4'b0000;     // Clear the bit command to prevent glitches
                        state   <= state_idle;  // Return to idle and wait for the next APB command
                    end

                    default : state <= state_idle;
                endcase
            end
        end
    endmodule
