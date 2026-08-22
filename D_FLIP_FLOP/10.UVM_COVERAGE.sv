import uvm_pkg::*;
`include "uvm_macros.svh"

class dff_coverage extends uvm_subscriber #(dff_sequence_item);
      `uvm_component_utils(dff_coverage)

      // 1. Local handle
      dff_sequence_item item;

      // 2. The Covergroup
      covergroup dff_cg;
        // REQUIRED: This tells the simulator to track the score for this
        // specific instance, which allows get_inst_coverage() to work!
        option.per_instance = 1;

        coverpoint_d: coverpoint item.d {
          bins saw_a_zero = {0};
          bins saw_a_one  = {1};
        }

        coverpoint_q: coverpoint item.q {
          bins saw_a_zero = {0};
          bins saw_a_one  = {1};
        }

        cross_d_q: cross coverpoint_d, coverpoint_q;
      endgroup

      // 3. Constructor
      function new(string name = "dff_coverage", uvm_component parent = null);
        super.new(name, parent);
        dff_cg = new();
      endfunction

      // 4. The Write Function (Catches the Broadcast)
      virtual function void write(dff_sequence_item t);
        // Because uvm_subscriber forces the argument to be named 't' in the background,
        // we take 't' and copy it into our local 'item'.
        item = t;
        dff_cg.sample();
      endfunction

      // ---------------------------------------------------------
      // 5. THE REPORT PHASE (Prints the scores at the very end)
      // ---------------------------------------------------------
      virtual function void report_phase(uvm_phase phase);
        real global_score;
        real instance_score;

        // Calculate both scores using the built-in functions
        global_score   = dff_cg.get_coverage();
        instance_score = dff_cg.get_inst_coverage();

        // Print both scores to the screen!
        `uvm_info("COV_SCORE", $sformatf("GLOBAL Average Coverage: %0.2f %%", global_score), UVM_NONE)
        `uvm_info("COV_SCORE", $sformatf("THIS INSTANCE Coverage: %0.2f %%", instance_score), UVM_NONE)

      endfunction

    endclass
