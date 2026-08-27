  import uvm_pkg::*;
    `include "uvm_macros.svh"

    // FIXED: Changed 'import' to 'class'
    class apb_sequencer extends uvm_sequencer #(apb_transaction);

      // Register this COMPONENT with the UVM Factory
      `uvm_component_utils(apb_sequencer)

      // Constructor requires both a name and a parent!
      function new(string name = "apb_sequencer", uvm_component parent);
        super.new(name, parent);
      endfunction

    endclass
