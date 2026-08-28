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

        // --------------------------------------------------------------------
        // APB INTERFACE (Connections to the CPU Registers)
        // --------------------------------------------------------------------
        input  wire [7:0]  din,        // 8-bit data loaded from the APB TX Register.

        // THE PROTOCOL ACKNOWLEDGE PORTS (The 9th Bit of I2C)
        input  wire        ack_in,     // Data from CPU: The ACK/NACK value the Master must transmit to the Slave during a Master Read.
        output reg         ack_out,    // Data to CPU: The ACK/NACK value received from the Slave during a Master Write (routed to APB Status Register).

        input  wire        start,      // Command flag from APB Control Register (Trigger START condition)
        input  wire        write,      // Command flag from APB Control Register (Trigger 8-bit Master Write)
        input  wire        read,       // Command flag from APB Control Register (Trigger 8-bit Master Read)
        input  wire        stop,       // Command flag from APB Control Register (Trigger STOP condition)

        output reg  [7:0]  dout,       // 8-bit data successfully read from the Slave (routed to APB RX Register).
        output reg         cmd_ack,    // 1-clock-cycle hardware pulse to the APB logic indicating the full byte transfer is complete.
        output reg         i2c_busy,   // Status flag indicating the I2C FSM is active.

        // --------------------------------------------------------------------
        // BIT CONTROLLER INTERFACE (Connections to the physical hardware driver)
        // --------------------------------------------------------------------
        output reg  [3:0]  bit_cmd,    // 4-bit One-Hot command telling the Bit Controller FSM what physical action to perform:
                                       // 4'b0001 = START, 4'b0010 = STOP, 4'b0100 = WRITE 1 BIT, 4'b1000 = READ 1 BIT.

        output wire        bit_din,    // The actual '1' or '0' logic level the Bit Controller will drive onto the SDA wire.

        input  wire        bit_ack,    // Hardware Handshake Pulse: The Bit Controller pulses this High for 1 clock cycle
                                       // when it has physically finished transmitting or reading exactly 1 bit on the bus.

        input  wire        bit_dout    // The actual '1' or '0' logic level the Bit Controller just sampled from the SDA wire.
    );

        // ====================================================================
        // FSM State Encodings
        // ====================================================================
        localparam state_idle  = 3'd0; // Waiting for command from APB.
        localparam state_start = 3'd1; // Waiting for Bit Controller to finish physical START.
        localparam state_data  = 3'd2; // The 8-bit loop (Shifting data out to bus or in from bus).
        localparam state_ack   = 3'd3; // The 9th bit phase (Evaluating Master-ACK or Slave-ACK).
        localparam state_stop  = 3'd4; // Waiting for Bit Controller to finish physical STOP.
        localparam state_done  = 3'd5; // 1-cycle cleanup state to assert cmd_ack to the APB.

        reg [2:0] state;               // FSM current state register.
        reg [2:0] bit_counter;         // 3-bit counter to track the 8 data bits (counts 7 down to 0).
        reg [7:0] shift_reg;           // Parallel-to-Serial / Serial-to-Parallel conversion register.

        // ====================================================================
        // COMBINATORIAL MULTIPLEXER (bit_din logic)
        // This instantly routes the correct bit to the Bit Controller to prevent
        // 1-clock-cycle delays (race conditions) when entering new states.
        // ====================================================================
        assign bit_din =
            // Condition 1: Master Write Phase
            // If we are transmitting the 8 data bits, route the MSB of the shift register to the Bit Controller.
            (state == state_data && write) ? shift_reg[7] :

            // Condition 2: Master Read Phase (The 9th Bit)
            // If we finished reading 8 bits, the Master is required to transmit an ACK to the Slave.
            // Route the CPU's 'ack_in' signal to the Bit Controller.
            (state == state_ack && !write) ? ack_in :

            // Condition 3: Default Safe State
            // For all other states (Idle, Start, Stop), force the transmit data to 0.
            1'b0;

        // ====================================================================
        // MAIN FSM SEQUENTIAL LOGIC
        // ====================================================================
        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                // Asynchronous Reset: Clear all registers and outputs.
                state       <= state_idle;
                dout        <= 8'h00;
                bit_cmd     <= 4'b0000;
                ack_out     <= 1'b0;
                cmd_ack     <= 1'b0;
                i2c_busy    <= 1'b0;
                bit_counter <= 3'd0;
                shift_reg   <= 8'h00;
            end else begin
                // Default Assignment: cmd_ack must only be a 1-cycle pulse.
                cmd_ack <= 1'b0;

                case(state)
                    // --------------------------------------------------------
                    // STATE 0: IDLE
                    // --------------------------------------------------------
                    state_idle : begin
                        // Check if APB Control Register asserted any command flags.
                        if((start || write || read || stop) && !cmd_ack) begin
                            i2c_busy  <= 1'b1;         // Assert bus busy flag.
                            shift_reg <= din;          // Load the parallel APB data into the shift register.

                            // Priority 1: Does the transaction require a START condition?
                            if (start) begin
                                state   <= state_start;
                                bit_cmd <= 4'b0001;    // Command Bit Controller to execute START (0001).
                            end else begin
                                // If no START is required, transition directly to data phase.
                                state       <= state_data;
                                bit_counter <= 3'd7;   // Initialize bit counter for MSB-first transmission.

                                if(write) bit_cmd <= 4'b0100; // Command Bit Controller to execute WRITE 1 BIT (0100).
                                else      bit_cmd <= 4'b1000; // Command Bit Controller to execute READ 1 BIT (1000).
                            end
                        end else begin
                            // Maintain idle state and clear Bit Controller commands.
                            i2c_busy <= 1'b0;
                            bit_cmd  <= 4'b0000;
                        end
                    end

                    // --------------------------------------------------------
                    // STATE 1: START
                    // --------------------------------------------------------
                    state_start : begin
                        // Wait for Hardware Handshake: Bit Controller finished the physical START.
                        if(bit_ack) begin
                            state       <= state_data;
                            bit_counter <= 3'd7;

                            if(write) bit_cmd <= 4'b0100; // Proceed to WRITE 1 BIT.
                            else      bit_cmd <= 4'b1000; // Proceed to READ 1 BIT.
                        end
                    end

                    // --------------------------------------------------------
                    // STATE 2: DATA (The 8-Bit Loop)
                    // --------------------------------------------------------
                    state_data : begin
                        // Wait for Hardware Handshake: Bit Controller finished exactly 1 bit.
                        if(bit_ack) begin

                            // Shift Register Management
                            if(read) begin
                                // Serial-to-Parallel: Shift left and insert the sampled bit (bit_dout) into the LSB.
                                shift_reg <= (shift_reg << 1) | bit_dout;
                            end else begin
                                // Parallel-to-Serial: Shift left to expose the next Most Significant Bit.
                                shift_reg <= shift_reg << 1;
                            end

                            // Counter Management
                            if (bit_counter == 3'd0) begin
                                // All 8 bits have been processed. Transition to the 9th bit (ACK Phase).
                                state <= state_ack;

                                // Protocol Requirement (Command Reversal):
                                // If Master just Wrote data, it must READ the ACK from the Slave.
                                // If Master just Read data, it must WRITE the ACK to the Slave.
                                if(write) bit_cmd <= 4'b1000;
                                else      bit_cmd <= 4'b0100;

                            end else begin
                                // Not finished. Decrement counter and command another bit operation.
                                bit_counter <= bit_counter - 3'd1;

                                if(write) bit_cmd <= 4'b0100;
                                else      bit_cmd <= 4'b1000;
                            end
                        end
                    end

                    // --------------------------------------------------------
                    // STATE 3: ACK (The 9th Bit Handshake)
                    // --------------------------------------------------------
                    state_ack : begin
                        // Wait for Hardware Handshake: Bit Controller finished the 9th bit.
                        if(bit_ack) begin

                            // If Master Write: The Slave drove the SDA line.
                            // Capture the physical wire value (bit_dout) and route it to APB Status Register (ack_out).
                            if(write) ack_out <= bit_dout;

                            // If Master Read: We have a full 8-bit byte from the Slave.
                            // Route the completely formed shift_reg to the APB RX Register (dout).
                            if(read)  dout <= shift_reg;

                            // Check if APB Control Register requested a STOP condition to end the transfer.
                            if(stop) begin
                                state   <= state_stop;
                                bit_cmd <= 4'b0010;  // Command Bit Controller to execute STOP (0010).
                            end else begin
                                // If no STOP requested, transition to done (burst mode continuation).
                                state   <= state_done;
                            end
                        end
                    end

                    // --------------------------------------------------------
                    // STATE 4: STOP
                    // --------------------------------------------------------
                    state_stop : begin
                        // Wait for Hardware Handshake: Bit Controller finished the physical STOP.
                        if(bit_ack) state <= state_done;
                    end

                    // --------------------------------------------------------
                    // STATE 5: DONE (Cleanup)
                    // --------------------------------------------------------
                    state_done : begin
                        cmd_ack <= 1'b1;        // Assert 1-cycle hardware pulse to APB logic indicating completion.
                        bit_cmd <= 4'b0000;     // Clear command to Bit Controller to prevent accidental re-triggering.
                        state   <= state_idle;  // Return to idle state.
                    end

                    default : state <= state_idle;
                endcase
            end
        end
    endmodule
