import uvm_pkg::*;
    `include "uvm_macros.svh"

    class apb_transaction extends uvm_sequence_item;

      // Register this class with the UVM Factory
      `uvm_object_utils(apb_transaction)

      // -----------------------------------------------------------------------
      // 1. Randomize the Inputs (What the CPU wants to do)
      // -----------------------------------------------------------------------
      rand bit [31:0] PADDR;   // Which register are we talking to?
      rand bit        PWRITE;  // Are we Reading (0) or Writing (1)?
      rand bit [31:0] PWDATA;  // What data are we writing?

      // -----------------------------------------------------------------------
      // 2. Outputs (What comes back from the DUT)
      // -----------------------------------------------------------------------
      // NOT random. The Monitor will fill this in when the DUT responds.
      bit [31:0] PRDATA;

      // -----------------------------------------------------------------------
      // 3. Smart Constraints (Interview Winner!)
      // -----------------------------------------------------------------------
      // Your apb_i2c_core.v only has 5 registers (0x0, 0x1, 0x2, 0x3, 0x4).
      // We constrain the randomizer so it only generates valid addresses!
      constraint valid_address {
        PADDR inside {32'h0, 32'h1, 32'h2, 32'h3, 32'h4};
      }

      // -----------------------------------------------------------------------
      // 4. Constructor
      // -----------------------------------------------------------------------
      // Added quotes around the default string name
      function new(string name = "apb_transaction");
        super.new(name);
      endfunction

      // -----------------------------------------------------------------------
      // 5. Custom Print Function
      // -----------------------------------------------------------------------
      function void print_trans();
        // FIXED: Used backtick (`) and added quotes inside $sformatf
        // Using %0h to print in HEX instead of decimal, which is standard for addresses
        `uvm_info("TRANSACTION", $sformatf("ADDR: %0h | WRITE: %0b | WDATA: %0h | RDATA: %0h",
                                            PADDR, PWRITE, PWDATA, PRDATA), UVM_LOW)
      endfunction

    endclass
