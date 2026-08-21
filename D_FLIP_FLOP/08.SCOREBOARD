import uvm_pkg::*;
`include "uvm_macros.svh"

 class dff_scoreboard extends uvm_scoreboard;

      `uvm_component_utils(dff_scoreboard)
      uvm_analysis_imp #(dff_sequence_item, dff_scoreboard) item_collected_export;

      // Create our FIFO Queue to store the history of D!
      logic expected_queue[$];

      function new(string name = "dff_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        item_collected_export = new("item_collected_export", this);
      endfunction

      virtual function void write(dff_sequence_item item);
        logic expected_q;

        // 1. Put the new D value at the back of the line
        expected_queue.push_back(item.d);

        // 2. We only check Q if we have an expected value ready!
        if (expected_queue.size() > 1) begin

          // Take the oldest D value from the front of the line
          expected_q = expected_queue.pop_front();

          if (item.q === expected_q)
            `uvm_info("SCOREBOARD", $sformatf("PASS, Q=%b matches old D=%b", item.q, expected_q), UVM_LOW)
          else
            `uvm_error("SCOREBOARD", $sformatf("FAIL, Q=%b does NOT match old D=%b", item.q, expected_q))

        end
      endfunction

    endclass
