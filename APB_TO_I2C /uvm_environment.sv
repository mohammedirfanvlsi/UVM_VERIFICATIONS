import uvm_pkg::*;
    `include "uvm_macros.svh"

     class apb_environment extends uvm_env;
      `uvm_component_utils(apb_environment)

      // -----------------------------------------------------
      // 1. Declare our 4 Main Components
      // -----------------------------------------------------
      apb_agent      agent;       // The APB Protocol Team (Driver, Sqr, Mon)
      i2c_monitor    i2c_mon;     // The I2C Protocol Spy Camera
      apb_scoreboard scb;         // The Dual-Port End-to-End Scoreboard
      apb_coverage   cov;         // <-- ADDED BACK: Your Coverage Collector!

      function new(string name = "apb_environment", uvm_component parent);
        super.new(name, parent);
      endfunction

      // -----------------------------------------------------
      // 2. Build Phase (Create them in memory)
      // -----------------------------------------------------
      function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent   = apb_agent::type_id::create("agent", this);
        i2c_mon = i2c_monitor::type_id::create("i2c_mon", this);
        scb     = apb_scoreboard::type_id::create("scb", this);
        cov     = apb_coverage::type_id::create("cov", this); // <-- Built it!
      endfunction

      // -----------------------------------------------------
      // 3. Connect Phase (Plug the cables together!)
      // -----------------------------------------------------
      function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // CABLE 1: APB Monitor -> Scoreboard (Port 1)
        // Sends the "Expected" APB data to the scoreboard
        agent.mon.item_collected_port.connect(scb.apb_port);

        // CABLE 2: I2C Monitor -> Scoreboard (Port 2)
        // Sends the "Actual" I2C data to the scoreboard
        i2c_mon.item_collected_port.connect(scb.i2c_port);

        // CABLE 3: APB Monitor -> Coverage Collector
        // <-- ADDED BACK: Send APB transactions to your coverage group!
        agent.mon.item_collected_port.connect(cov.analysis_export);

      endfunction

    endclass
