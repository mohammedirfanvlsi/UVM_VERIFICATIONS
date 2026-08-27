import uvm_pkg::*;
    `include "uvm_macros.svh"

    class i2c_monitor extends uvm_monitor;
      `uvm_component_utils(i2c_monitor)

      virtual apb_i2c_if vif;
      uvm_analysis_port #(i2c_transaction) item_collected_port;

      function new(string name = "i2c_monitor", uvm_component parent);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
      endfunction

      function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual apb_i2c_if)::get(this, "", "vif", vif))
          `uvm_fatal("I2C_MON", "Could not get virtual interface!")
      endfunction

         
       task run_phase(uvm_phase phase);
        i2c_transaction tx;
        logic [7:0] captured_byte;

        // Wait for the single START at the very beginning
        @(negedge vif.sda iff vif.scl === 1'b1);

        forever begin
          tx = i2c_transaction::type_id::create("tx");

          // Capture 8 bits of data
          for (int i = 7; i >= 0; i--) begin
            @(posedge vif.scl);
            #1;
            @(negedge vif.scl);
            captured_byte[i] = vif.sda;
          end

          tx.i2c_data = captured_byte;
          item_collected_port.write(tx);

          // Skip the 9th ACK bit
          @(posedge vif.scl);
          @(negedge vif.scl);
        end
      endtask
        
 endclass
