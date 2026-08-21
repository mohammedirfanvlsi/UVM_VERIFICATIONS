import uvm_pkg::*;
`include "uvm_macros.svh"

class dff_env extends uvm_env;

      `uvm_component_utils(dff_env)

      // ---------------------------------------------------------
      // 1. DECLARE HANDLES (The empty Lego spaces)
      // ---------------------------------------------------------
      dff_agent      agent;
      dff_scoreboard sb;
      dff_coverage   cov;

      // 2. CONSTRUCTOR
      function new(string name = "dff_env", uvm_component parent = null);
        super.new(name, parent);
      endfunction

      // ---------------------------------------------------------
      // 3. THE BUILD PHASE (Time 0)
      // We use the factory to physically create our three blocks.
      // ---------------------------------------------------------
      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase); // Always call super!

        agent = dff_agent::type_id::create("agent", this);
        sb    = dff_scoreboard::type_id::create("sb", this);
        cov   = dff_coverage::type_id::create("cov", this);

      endfunction

      // ---------------------------------------------------------
      // 4. THE CONNECT PHASE (Wiring everything together)
      // ---------------------------------------------------------
      virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase); // Always call super!

        // CONNECTION 1: Agent to Scoreboard
        // We connect the Agent's broadcast antenna directly to the
        // receiver port we manually built inside the Scoreboard.
        agent.agent_ap.connect(sb.item_collected_export);

        // CONNECTION 2: Agent to Coverage
        // We connect the exact same Agent antenna to the Coverage receiver!
        // NOTE: 'analysis_export' is the hidden name of the receiver port
        // that UVM built for us inside the uvm_subscriber base class!
        agent.agent_ap.connect(cov.analysis_export);

      endfunction

    endclass
