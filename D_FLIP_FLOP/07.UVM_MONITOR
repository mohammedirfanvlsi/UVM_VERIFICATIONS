import uvm_pkg::*;
`include "uvm_macros.svh"


// Extend from the built-in monitor base class
    class dff_monitor extends uvm_monitor;

      `uvm_component_utils(dff_monitor)

      // The virtual interface to spy on the physical wires
  virtual inf vif;
      // ---------------------------------------------------------
      // UVM TLM (Module 09)
      // This is the "Radio Broadcast Tower" that will send
      // the spied packet to the Scoreboard.
      // ---------------------------------------------------------
      uvm_analysis_port #(dff_sequence_item) item_collected_port;

      function new(string name = "dff_monitor", uvm_component parent = null);
        super.new(name, parent);
        // We must allocate memory for the TLM port using 'new'
        item_collected_port = new("item_collected_port", this);
      endfunction
      
       // ---------------------------------------------------------
      // THE BUILD PHASE
      // The Monitor must download 'vif' from the database too!
      // ---------------------------------------------------------
      virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Open the locker and grab the remote control!
        if (!uvm_config_db#(virtual inf)::get(this, "", "vif", vif)) begin
          `uvm_fatal("MON", "ERROR: Monitor could not find vif in database!")
        end

      endfunction

      // ---------------------------------------------------------
      // RUN PHASE
      // ---------------------------------------------------------
     virtual task run_phase(uvm_phase phase);
        dff_sequence_item item;
        forever begin
          @(negedge vif.clk);

          

          if (vif.rst_n == 1) begin
            item = dff_sequence_item::type_id::create("item");
            item.d = vif.d;
            item.q = vif.q;
            item_collected_port.write(item);
          end
        end
      endtask
    endclass
