import uvm_pkg::*;
`include "uvm_macros.svh"


class dff_driver extends uvm_driver #(dff_sequence_item);
      `uvm_component_utils(dff_driver)

  virtual inf vif;
  
      function new(string name = "dff_driver", uvm_component parent = null);
        super.new(name, parent);
        
         if (!uvm_config_db#(virtual inf)::get(this, "", "vif", vif)) begin
          `uvm_fatal("DRV", "ERROR: The Driver opened the mailbox but it was empty!")
        end
      endfunction

      task run_phase(uvm_phase phase);

        // Using 'item' to perfectly match our Sequence code!
        dff_sequence_item item;

        forever begin
          // We use the HIDDEN TLM port built into the uvm_driver base class
          seq_item_port.get_next_item(item);

          // Drive hardware
          @(posedge vif.clk);
          vif.d <= item.d;

          // Complete the handshake using the HIDDEN TLM port
          seq_item_port.item_done();
        end
      endtask
    endclass
