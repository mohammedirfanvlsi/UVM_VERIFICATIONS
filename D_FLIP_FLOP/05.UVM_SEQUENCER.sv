import uvm_pkg::*;
`include "uvm_macros.svh"


// We tell the Sequencer to only accept 'dff_sequence_item' packets
    class dff_sequencer extends uvm_sequencer #(dff_sequence_item);

      // This is a permanent block, so we use component_utils
      `uvm_component_utils(dff_sequencer)

      function new(string name = "dff_sequencer", uvm_component parent = null);
        super.new(name, parent);
      endfunction

    endclass
