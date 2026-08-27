import uvm_pkg::*;
    `include "uvm_macros.svh"

     `uvm_analysis_imp_decl(_apb)
    `uvm_analysis_imp_decl(_i2c)

    class apb_scoreboard extends uvm_scoreboard;
      `uvm_component_utils(apb_scoreboard)

      // PORT 1: Receives APB packets (Expected Data)
      uvm_analysis_imp_apb #(apb_transaction, apb_scoreboard) apb_port;

      // PORT 2: Receives I2C packets (Actual Data)
      uvm_analysis_imp_i2c #(i2c_transaction, apb_scoreboard) i2c_port;

      // This software variable saves the payload we want to transmit
      logic [7:0] expected_i2c_payload;

      function new(string name = "apb_scoreboard", uvm_component parent);
        super.new(name, parent);
        apb_port = new("apb_port", this);
        i2c_port = new("i2c_port", this);
      endfunction

      // -----------------------------------------------------------------
      // FUNCTION 1: This runs when the APB Monitor broadcasts a packet
      // -----------------------------------------------------------------
      virtual function void write_apb(apb_transaction req);

        // If the CPU is writing data to Address 0x3 (Transmit Register)...
        if (req.PADDR == 32'h3 && req.PWRITE == 1'b1) begin
          // Save it! We expect this exact data to come out of the I2C wires later.
          expected_i2c_payload = req.PWDATA[7:0];
          `uvm_info("SCB", $sformatf("CPU wants to send: %0h", expected_i2c_payload), UVM_NONE)
        end

      endfunction

      // -----------------------------------------------------------------
      // FUNCTION 2: This runs when the I2C Monitor broadcasts a packet
      // -----------------------------------------------------------------
      virtual function void write_i2c(i2c_transaction req);

        // The I2C Monitor captured a physical byte! Does it match what the APB bus sent?
        if (req.i2c_data === expected_i2c_payload) begin
          `uvm_info("SCB", $sformatf("PASS! APB sent %0h, and I2C output %0h!", expected_i2c_payload, req.i2c_data), UVM_NONE)
        end else begin
          `uvm_error("SCB", $sformatf("FAIL! APB sent %0h, but I2C output %0h!", expected_i2c_payload, req.i2c_data))
        end

      endfunction

    endclass
