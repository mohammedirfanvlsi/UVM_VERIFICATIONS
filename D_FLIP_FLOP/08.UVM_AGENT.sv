import uvm_pkg::*;
`include "uvm_macros.svh"

class dff_agent extends uvm_driver;
  
  `uvm_component_utils(dff_agent)
  
  dff_sequencer sqr;
  dff_driver drv;
  dff_monitor mon;
  
  uvm_analysis_port #(dff_sequence_item) agent_ap;  
  function new(string name = "dff_agent",uvm_component parent = null);
    
    super.new(name,parent);
    
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
    
    super.build_phase(phase);
    
    sqr = dff_sequencer::type_id::create("sqr",this);
    drv = dff_driver::type_id::create("drv",this);
    mon = dff_monitor::type_id::create("mon",this);
    
    agent_ap = new("agent_ap",this);
    
  endfunction
  
  virtual function void connect_phase(uvm_phase phase);
    
    super.connect_phase(phase);
    
    drv.seq_item_port.connect(sqr.seq_item_export);
    
  mon.item_collected_port.connect(this.agent_ap);    
  endfunction
  
endclass
