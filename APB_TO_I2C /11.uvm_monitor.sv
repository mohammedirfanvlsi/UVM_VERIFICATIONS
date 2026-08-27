 import uvm_pkg::*;
    `include "uvm_macros.svh"

    // Note: uvm_monitor does not take a parameter like uvm_driver does!
    class apb_monitor extends uvm_monitor;

      // FIXED: Changed 'apb_driver' to 'apb_monitor'
      `uvm_component_utils(apb_monitor)

      // FIXED: Removed backtick (`). This is a broadcast megaphone to send
      // captured packets to the Scoreboard.
      uvm_analysis_port #(apb_transaction) item_collected_port;

      // The remote control (Security Camera feed)
    virtual apb_i2c_if vif;
      // -----------------------------------------------------------------------
      // CONSTRUCTOR
      // -----------------------------------------------------------------------
      function new(string name = "apb_monitor", uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
      endfunction

      // -----------------------------------------------------------------------
      // BUILD PHASE
      // -----------------------------------------------------------------------
      function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_i2c_if)::get(this, "", "vif", vif)) begin          `uvm_fatal("MON", "Failed to get virtual interface from config_db!")
        end
      endfunction

      // -----------------------------------------------------------------------
      // RUN PHASE (The Security Camera Logic)
      // -----------------------------------------------------------------------

      task run_phase(uvm_phase phase);
        apb_transaction req;
        req = apb_transaction::type_id::create("req");

        forever begin
          @(vif.cb); // Wait for the clock heartbeat

          // Read from the raw wires (vif.PSEL) instead of the clocking block (vif.cb.PSEL)
          if (vif.PSEL === 1'b1 && vif.PENABLE === 1'b1 && vif.PREADY === 1'b1) begin
            req.PADDR  = vif.PADDR;
            req.PWRITE = vif.PWRITE;

            if (vif.PWRITE === 1'b1) begin
              req.PWDATA = vif.PWDATA;
            end else begin
              req.PRDATA = vif.PRDATA;
            end

            // Send the captured data to the Scoreboard!
            item_collected_port.write(req);
          end
        end
      endtask
    endclass
