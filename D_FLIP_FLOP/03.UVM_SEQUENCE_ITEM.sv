 // 1. We must include the UVM library macros and import the UVM package
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ---------------------------------------------------------
    // DFF SEQUENCE ITEM (Transaction)
    // This class represents a single packet of data going into the DFF
    // ---------------------------------------------------------
    class dff_sequence_item extends uvm_sequence_item;

      // ---------------------------------------------------------
      // THE DATA VARIABLES
      // ---------------------------------------------------------
      // 'rand' means we can randomize this input later to generate random 1s and 0s
      rand logic d;

      // We do not randomize 'q' because Q is the output we receive from the design
      logic      q;

      // ---------------------------------------------------------
      // MODULE 04: UVM FACTORY METHOD
      // ---------------------------------------------------------
      // This macro registers this exact class into the UVM Factory.
      // Because this is a "data object" (not a static testbench component),
      // we use the `uvm_object_utils macro.
      `uvm_object_utils(dff_sequence_item)

      // The Factory strictly requires every class to have a constructor function.
      // For a sequence_item, the constructor takes one argument: a string "name".
      function new(string name = "dff_sequence_item");
        // We pass the name up to the parent class (uvm_sequence_item) using 'super'
        super.new(name);
      endfunction

      // ---------------------------------------------------------
      // MODULE 03: REPORTING
      // ---------------------------------------------------------
      // Let's write a function to print our data.
      // Notice we use `uvm_info instead of $display!
      function void print_item();

        // `uvm_info takes 3 arguments:
        // Arg 1 (ID): A string tag so you know where the message came from.
        // Arg 2 (MSG): The actual string you want to print. We use $sformatf to insert variables.
        // Arg 3 (VERBOSITY): UVM_LOW means this is an important message, print it by default!

        `uvm_info("DFF_ITEM", $sformatf("Value of D = %0b, Value of Q = %0b", d, q), UVM_LOW)

      endfunction

    endclass
