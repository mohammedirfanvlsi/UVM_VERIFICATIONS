  import uvm_pkg::*;
    `include "uvm_macros.svh"

    class apb_agent extends uvm_agent;

      `uvm_component_utils(apb_agent)

      // 1. Declare the children
      apb_sequencer sqr;
      apb_driver    drv;
      apb_monitor   mon;

      // FIXED: Correct syntax for Analysis Port
      uvm_analysis_port #(apb_transaction) agent_ap;

      // 2. Constructor
      function new(string name = "apb_agent", uvm_component parent);
        super.new(name, parent);
      endfunction

      // 3. Build Phase
      function void build_phase(uvm_phase phase);
        // FIXED: Changed super.new to super.build_phase
        super.build_phase(phase);

        // The Monitor is ALWAYS built (Active or Passive, we always watch)
        mon = apb_monitor::type_id::create("mon", this);

        // INTERVIEW PRO-TIP: Only build Driver & Sequencer if the Agent is ACTIVE
        if (get_is_active() == UVM_ACTIVE) begin
          sqr = apb_sequencer::type_id::create("sqr", this);
          drv = apb_driver::type_id::create("drv", this);
        end

        // Build the analysis port
        agent_ap = new("agent_ap", this);
      endfunction

      // 4. Connect Phase
      // FIXED: Added 'uvm_phase' type to the argument
      function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Only connect the Driver and Sequencer if they were actually built!
        if (get_is_active() == UVM_ACTIVE) begin
          // This is YOU (the Agent) plugging the HDMI cable!
          drv.seq_item_port.connect(sqr.seq_item_export);
        end

        // FIXED: Corrected the analysis port connection syntax.
        // Connect the Monitor's broadcast port to the Agent's broadcast port,
        // so data can flow up to the Scoreboard!
        mon.item_collected_port.connect(agent_ap);

      endfunction

    endclass
