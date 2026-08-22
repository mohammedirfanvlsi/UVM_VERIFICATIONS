import uvm_pkg::*;
`include "uvm_macros.svh"

class dff_test extends uvm_test;
      `uvm_component_utils(dff_test)

      // 1. Declare the Environment and the Sequence
      dff_env      env;
      dff_sequence seq;

      function new(string name = "dff_test", uvm_component parent = null);
        super.new(name, parent);
      endfunction

      // 2. Build Phase
      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create the Environment
        env = dff_env::type_id::create("env", this);

        // Create the Sequence
        seq = dff_sequence::type_id::create("seq");
      endfunction

      // 3. Run Phase
      virtual task run_phase(uvm_phase phase);

        // Raise an objection (This tells UVM "Do not end the simulation yet!")
        phase.raise_objection(this);

        `uvm_info("TEST", "Starting the Sequence!", UVM_LOW)

        // START THE SEQUENCE!
        // We tell the sequence to run on the Sequencer located inside our Agent.
        seq.start(env.agent.sqr);

        // Drop the objection (This tells UVM "I am finished, you can end the simulation.")
        phase.drop_objection(this);

      endtask
    endclass
