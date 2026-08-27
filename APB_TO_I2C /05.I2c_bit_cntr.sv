// ========================================================================
// Module Name: i2c_bit_cntr (I2C Bit-Level Controller)
// Description:
//   This module handles individual bit operations (START, STOP, Write Bit, Read Bit)
//   on the physical I2C pins using a 4-phase State Machine (A, B, C, D)
//   synchronized by clk_en.
// ========================================================================


module i2c_bit_cntr (
        input  wire        clk,        // Fast system clock (e.g., 100MHz)
        input  wire        rst_n,      // Active-low reset
        input  wire        clk_en,     // Slow tick pulse (e.g., 100kHz) defining the actual I2C speed
        input  wire [3:0]  cmd,        // 4-bit command received from Byte Controller (e.g., 0100 for Write)
        input  wire        din,        // The single 1 or 0 bit to transmit (comes from bit_din)
        output reg         dout,       // The single 1 or 0 bit sampled from the physical I2C wire
        output reg         cmd_ack,    // Pulses High for 1 clock cycle to say "1 bit is done!"
        output reg         scl_oen,    // SCL Output Enable (0 = force wire Low, 1 = release wire High)
        output reg         sda_oen,    // SDA Output Enable (0 = force wire Low, 1 = release wire High)
        input  wire        scl_in,     // Feedback wire (reads actual physical SCL state)
        input  wire        sda_in      // Feedback wire (reads actual physical SDA state)
    );

        // Standard I2C requires 4 phases to transmit a single bit safely.
        localparam state_idle     = 3'd0;  // Resting
        localparam state_A        = 3'd1;  // Phase A: SCL is Low, safely change the SDA data
        localparam state_B        = 3'd2;  // Phase B: SCL goes High, data must be stable
        localparam state_c        = 3'd3;  // Phase C: SCL stays High, safely read the data
        localparam state_d        = 3'd4;  // Phase D: SCL goes Low again, bit is complete

        // The new debounce state filters out glitches
        localparam state_debounce = 3'd5;

        reg [2:0] state;               // Current state in the 4-phase I2C cycle
        reg [3:0] active_cmd;          // Locked copy of the command so it can't change mid-bit

        always @(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                state      <= state_idle;
                active_cmd <= 4'b0000;
                cmd_ack    <= 1'b0;
                scl_oen    <= 1'b1;    // 1 means release to High-Z (Safe default)
                sda_oen    <= 1'b1;    // 1 means release to High-Z (Safe default)
            end else begin
                cmd_ack <= 1'b0;       // Acknowledge pulse defaults to 0 every clock cycle

                case (state)
                    state_idle : begin
                        // If Byte Controller gives us a valid command...
                        if(cmd != 4'b0000 && !cmd_ack) begin
                            // Do NOT jump to state_A immediately!
                            // Jump to debounce to verify it's a real command, not a glitch.
                            state <= state_debounce;
                        end
                    end

                    // =========================================================================
                    // THE GHOST PULSE FILTER (Debounce State):
                    // The Byte Controller has a tiny synchronization glitch where it leaves the
                    // OLD command (4'b1000 READ) on the line for exactly 1 clock cycle before
                    // putting the NEW command (4'b0100 WRITE) on the line.
                    // By forcing the Bit Controller to wait 1 clock cycle here in state_debounce,
                    // the stale "Ghost Pulse" disappears, and we safely capture the real command!
                    // =========================================================================
                    state_debounce : begin
                        if (cmd != 4'b0000) begin
                            // The glitch is gone. Save the pure, real command and begin Phase A!
                            active_cmd <= cmd;
                            state      <= state_A;
                        end else begin
                            // If it was just a glitch and went back to 0, go back to sleep.
                            state      <= state_idle;
                        end
                    end

                    // -------------------------------------------------------------
                    // Phase A (Setup Phase)
                    // SCL is pulled Low. While SCL is Low, it is safe to wiggle SDA
                    // without accidentally causing a START or STOP condition.
                    // -------------------------------------------------------------
                    state_A : begin
                        if(clk_en) begin // Wait for the slow I2C tick
                            state   <= state_B;
                            scl_oen <= 1'b0;         // Pull SCL Clock Low

                            case(active_cmd)
                                4'b0001 : sda_oen <= 1'b1; // START setup: SDA must start High
                                4'b0010 : sda_oen <= 1'b0; // STOP setup: SDA must start Low
                                4'b0100 : sda_oen <= din;  // WRITE: Put our actual data bit on the SDA wire
                                4'b1000 : sda_oen <= 1'b1; // READ: Release SDA to High-Z so slave can talk
                                default : ;
                            endcase
                        end
                    end

                    // -------------------------------------------------------------
                    // Phase B (Clock Rise Phase)
                    // SCL is released to go High. Data must be perfectly stable now.
                    // -------------------------------------------------------------
                    state_B : begin
                        if(clk_en) begin
                            state   <= state_c;
                            scl_oen <= 1'b1;         // Release SCL Clock to go High

                            case(active_cmd)
                                // If generating START: Pull SDA Low WHILE SCL is High.
                                // (This unique movement is how I2C detects a START condition!)
                                4'b0001 : sda_oen <= 1'b0;

                                // If generating STOP: Keep SDA Low for now.
                                4'b0010 : sda_oen <= 1'b0;
                                default : ;
                            endcase
                        end
                    end

                    // -------------------------------------------------------------
                    // Phase C (Sample Phase)
                    // SCL remains High. It is now safe to sample the SDA wire.
                    // -------------------------------------------------------------
                    state_c : begin
                        if(clk_en) begin
                            state   <= state_d;
                            scl_oen <= 1'b1;         // Keep SCL High

                            case(active_cmd)
                                // If generating STOP: Release SDA High WHILE SCL is High.
                                // (This unique movement is how I2C detects a STOP condition!)
                                4'b0010 : sda_oen <= 1'b1;

                                // If READING: Sample the physical wire and save it to 'dout'
                                4'b1000 : dout    <= sda_in;
                                default : ;
                            endcase
                        end
                    end

                    // -------------------------------------------------------------
                    // Phase D (Hold Phase)
                    // SCL is pulled Low again. The single bit transmission is complete.
                    // -------------------------------------------------------------
                    state_d : begin
                        if(clk_en) begin
                            state   <= state_idle;   // Return to idle to wait for the next bit
                            cmd_ack <= 1'b1;         // Send 1-cycle pulse to Byte Controller: "I did it!"
                            scl_oen <= 1'b0;         // Pull SCL Low to end the bit cycle
                        end
                    end

                    default : state <= state_idle; // Failsafe
                endcase
            end
        end
    endmodule
