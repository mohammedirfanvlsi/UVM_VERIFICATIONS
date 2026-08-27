import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------------------------
    // 1. CLASS DECLARATION
    // -------------------------------------------------------------------------
    class apb_test extends uvm_test;

      // Register as a permanent COMPONENT in the UVM Factory
      `uvm_component_utils(apb_test)

      // -----------------------------------------------------------------------
      // 2. DECLARE THE MAJOR HANDLES
      // -----------------------------------------------------------------------
      apb_environment env; // The motherboard that holds everything
      apb_sequence    seq; // The software recipe that generates data

      // -----------------------------------------------------------------------
      // 3. CONSTRUCTOR
      // -----------------------------------------------------------------------
      // FIXED: Typo 'sting' to 'string'
      function new(string name = "apb_test", uvm_component parent = null);
        super.new(name, parent);
      endfunction

      // -----------------------------------------------------------------------
      // 4. BUILD PHASE (Creating the blocks)
      // -----------------------------------------------------------------------
      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create the Environment Component (Pass 'this' because it is a child)
        env = apb_environment::type_id::create("env", this);

        // Create the Sequence Object (No 'this' because it is a temporary object!)
        seq = apb_sequence::type_id::create("seq");

      endfunction

      // -----------------------------------------------------------------------
      // 5. RUN PHASE (Executing the simulation)
      // -----------------------------------------------------------------------
      virtual task run_phase(uvm_phase phase);

        // 1. Tell the simulator: "Wait! Do not end the simulation yet!"
        phase.raise_objection(this);

        // 2. Start generating data and pushing it into the physical sequencer
        seq.start(env.agent.sqr);

        // 3. Tell the simulator: "I am finished. You can end the simulation now."
        phase.drop_objection(this);

      endtask

    endclass
