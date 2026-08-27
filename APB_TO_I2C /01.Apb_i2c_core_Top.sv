
    `include "i2c_clk_gen.sv"
    `include "i2c_byte_cntr.sv"
    `include "i2c_bit_cnt.sv"
    

   module apb_i2c_core (
        // We pass the interface here. 'inf' is the interface name,
        // 'dut' is the modport, and 'bus' is the handle.
        apb_i2c_if.dut bus
    );

        // ========================================================================
        // 1. Register Declarations
        // ========================================================================
        reg [7:0] prer_lo; // Address 0x00: Prescale Low-byte
        reg [7:0] prer_hi; // Address 0x01: Prescale High-byte
        reg [7:0] ctr;     // Address 0x02: Control Register

        reg [7:0] txr;     // Address 0x03 (Write): Transmit register
        wire [7:0] rxr;    // Address 0x03 (Read): Receive register

        reg [7:0] cr;      // Address 0x04 (Write): Command register
        wire [7:0] sr;     // Address 0x04 (Read): Status register

        // ========================================================================
        // 2. Internal Wires connecting the Sub-modules
        // ========================================================================
        wire        clk_en;
        wire [3:0]  bit_cmd;
        wire        bit_din;
        wire        bit_dout;
        wire        bit_ack;

        wire        scl_oen;
        wire        sda_oen;
        wire        scl_in;
        wire        sda_in;

        wire [7:0]  byte_dout;
        wire        byte_ack;
        wire        byte_ack_out;
        wire        i2c_busy;

        // ========================================================================
        // 3. APB Read/Write Decode Logic
        // ========================================================================
        // FIXED: Added 'bus.' to PREADY, PSEL, PENABLE, PWRITE
        assign bus.PREADY = 1'b1;
        wire apb_write = bus.PSEL & bus.PENABLE & bus.PWRITE & bus.PREADY;
        wire apb_read  = bus.PSEL & bus.PENABLE & ~bus.PWRITE & bus.PREADY;

        // ========================================================================
        // 4. APB Register Write Logic (CPU -> Registers)
        // ========================================================================
        always @(posedge bus.PCLK or negedge bus.PRESETn) begin
            // FIXED: Changed 'bus.!PRESETn' to '!bus.PRESETn'
            if (!bus.PRESETn) begin
                prer_lo <= 8'hFF;
                prer_hi <= 8'hFF;
                ctr     <= 8'h00;
                txr     <= 8'h00;
                cr      <= 8'h00;
            end else begin
                if (apb_write) begin
                    // FIXED: Added 'bus.' to PADDR
                    case (bus.PADDR[2:0])
                        3'h0: prer_lo <= bus.PWDATA[7:0];
                        3'h1: prer_hi <= bus.PWDATA[7:0];
                        3'h2: ctr     <= bus.PWDATA[7:0];
                        3'h3: txr     <= bus.PWDATA[7:0];
                        3'h4: cr      <= bus.PWDATA[7:0];
                        default: ;
                    endcase
                end else begin
                    if (byte_ack) begin
                        cr[7:4] <= 4'b0000;
                    end
                end
            end
        end

        // ========================================================================
        // 5. APB Register Read Logic (Registers -> CPU)
        // ========================================================================
        always @(*) begin
            bus.PRDATA = 32'h0000_0000;
            if (apb_read) begin
                case (bus.PADDR[2:0])
                    3'h0: bus.PRDATA[7:0] = prer_lo;
                    3'h1: bus.PRDATA[7:0] = prer_hi;
                    3'h2: bus.PRDATA[7:0] = ctr;
                    3'h3: bus.PRDATA[7:0] = rxr;
                    3'h4: bus.PRDATA[7:0] = sr;
                    default: bus.PRDATA[7:0] = 8'h00;
                endcase
            end
        end

        // ========================================================================
        // 6. Connect Status (SR) and Receive (RXR) Wires
        // ========================================================================
        assign rxr = byte_dout;

        assign sr[7]   = byte_ack_out;
        assign sr[6]   = i2c_busy;
        assign sr[5:2] = 4'b0000;
        assign sr[1]   = i2c_busy;
        assign sr[0]   = byte_ack;

        // ========================================================================
        // 7. Physical Bidirectional Buffers (Tristate Logic)
        // ========================================================================
        // FIXED: Pushing the tristate values out to 'bus.scl' and 'bus.sda'
        assign bus.scl = (scl_oen == 1'b0) ? 1'b0 : 1'bz;
        assign bus.sda = (sda_oen == 1'b0) ? 1'b0 : 1'bz;

        // FIXED: Sampling the voltages from the interface back into internal wires
        assign scl_in = bus.scl;
        assign sda_in = bus.sda;

        // ========================================================================
        // 8. Module Instantiations (NO CHANGES NEEDED HERE)
        // ========================================================================

        i2c_clk_gen u_clock_gen (
            .clk      (bus.PCLK),
            .rst_n    (bus.PRESETn),
            .prescale ({prer_hi, prer_lo}),
            .scl_out  (scl_oen),
            .scl_in   (scl_in),
            .clk_en   (clk_en)
        );

        i2c_bit_cntr u_bit_ctrl (
            .clk      (bus.PCLK),
            .rst_n    (bus.PRESETn),
            .clk_en   (clk_en),
            .cmd      (bit_cmd),
            .din      (bit_din),
            .dout     (bit_dout),
            .cmd_ack  (bit_ack),
            .scl_oen  (scl_oen),
            .sda_oen  (sda_oen),
            .scl_in   (scl_in),
            .sda_in   (sda_in)
        );

        i2c_byte_cntr u_byte_ctrl (
            .clk      (bus.PCLK),
            .rst_n    (bus.PRESETn),
            .start    (cr[7] & ctr[7]),
            .stop     (cr[6] & ctr[7]),
            .read     (cr[5] & ctr[7]),
            .write    (cr[4] & ctr[7]),
            .ack_in   (cr[3]),
            .din      (txr),
            .dout     (byte_dout),
            .cmd_ack  (byte_ack),
            .ack_out  (byte_ack_out),
            .i2c_busy (i2c_busy),
            .bit_cmd  (bit_cmd),
            .bit_din  (bit_din),
            .bit_dout (bit_dout),
            .bit_ack  (bit_ack)
        );

    endmodule
