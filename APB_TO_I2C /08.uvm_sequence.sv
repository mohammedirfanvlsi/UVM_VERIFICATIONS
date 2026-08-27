import uvm_pkg::*;
    `include "uvm_macros.svh"
    class apb_sequence extends uvm_sequence #(apb_transaction);

      `uvm_object_utils(apb_sequence)

      function new(string name = "apb_sequence");
        super.new(name);
      endfunction

      // -----------------------------------------------------------------------
      // THE FIRMWARE ROUTINE (Task Body)
      // -----------------------------------------------------------------------
      task body();

        `uvm_info("SEQ", "=== STARTING APB-TO-I2C BRIDGE CONFIGURATION ===", UVM_LOW)

        // STEP 1: Set Clock Speed (Prescaler Low = 0xC8, High = 0x00)
        `uvm_do_with(req, {PADDR == 32'h0; PWRITE == 1'b1; PWDATA == 32'hC8;})
        `uvm_do_with(req, {PADDR == 32'h1; PWRITE == 1'b1; PWDATA == 32'h00;})

        // STEP 2: Turn on the Bridge (Control Register = 0x80)
        // This flips Bit 7 (Enable Core) to 1.
        `uvm_do_with(req, {PADDR == 32'h2; PWRITE == 1'b1; PWDATA == 32'h80;})

        `uvm_info("SEQ", "=== BRIDGE CONFIGURED. STARTING I2C TRANSFER ===", UVM_LOW)

        // =====================================================================
        // STEP 3: THE ADDRESS PHASE (Manual Setup)
        // =====================================================================
        // We must manually send the 7-bit Slave Address + 1-bit Write Flag.
        // Slave Address 0x5A << 1 = 0xB4.

        // Drop 0xB4 into the Transmit Register (0x3)
        `uvm_do_with(req, {PADDR == 32'h3; PWRITE == 1'b1; PWDATA == 32'hB4;})

        // Push the Launch Button! Write STA (Start) + WR (Write) to Command Reg (0x4)
        `uvm_do_with(req, {PADDR == 32'h4; PWRITE == 1'b1; PWDATA == 32'h90;})

        // Polling Loop: Ask the Status Register (0x4) "Are you done?"
        // Keep asking as long as Bit 1 (i2c_busy) is 1.
        do begin
          `uvm_do_with(req, {PADDR == 32'h4; PWRITE == 1'b0;})
        end while (req.PRDATA[1] == 1'b1);

        `uvm_info("SEQ", "=== ADDRESS PHASE COMPLETE. SLAVE IS LISTENING ===", UVM_LOW)

        // =====================================================================
        // STEP 4: THE DATA PHASE (UVM Randomization!)
        // =====================================================================
        // The Slave is listening. Now we can test it with completely RANDOM data!
        // Notice we DO NOT force PWDATA. UVM will randomize it automatically!

        // Drop RANDOM DATA into the Transmit Register (0x3)
       // =====================================================================
            // STEP 4: THE DATA PHASE (UVM Randomization!)
            // =====================================================================
            // Loop 10 times to test 10 random payloads!
        for (int i = 0; i < 30; i++) begin

              // Drop RANDOM DATA into the Transmit Register (0x3)
              `uvm_do_with(req, {PADDR == 32'h3; PWRITE == 1'b1;})
              

              // Push the Launch Button! Write WR (Write) to Command Reg (0x4)
          `uvm_do_with(req, {PADDR == 32'h4; PWRITE == 1'b1; PWDATA == 32'h10;})             // Polling Loop: Wait for the random data to finish sending...
              do begin
                `uvm_do_with(req, {PADDR == 32'h4; PWRITE == 1'b0;})
              end while (req.PRDATA[1] == 1'b1);

            end // End of loop!

            `uvm_info("SEQ", "=== ALL 10 TRANSFERS 100% COMPLETE! ===", UVM_LOW)
      endtask

    endclass
