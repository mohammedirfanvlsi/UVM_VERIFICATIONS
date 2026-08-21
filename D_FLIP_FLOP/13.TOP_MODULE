
 module tb_top;

      import uvm_pkg::*;
      `include "uvm_macros.svh"
    

    // 3. UVM Class Files (Strict Order!)
    `include "uvm_sequence_item.sv"
    `include "uvm_sequence.sv"
    `include "uvm_sequencer.sv"
    `include "uvm_driver.sv"
    `include "uvm_monitor.sv"
   `include "uvm_agent.sv"
    `include "uvm_scoreboard.sv"
    `include "uvm_coverage.sv"
    `include "uvm_env.sv"
    `include "uvm_test.sv"


      // 1. Generate the physical Clock and Reset
      logic clk;
      logic rst_n;

      initial begin
        clk = 0;
        forever #5 clk = ~clk;
      end

     initial begin
      vif.rst_n = 1;     // Start high
      #1 vif.rst_n = 0;  // Drop to 0 (This creates a perfect negedge!)
      #20 vif.rst_n = 1; // Turn back on
    end

      // ---------------------------------------------------------
      // INSTANTIATION (Using your Positional syntax!)
      // ---------------------------------------------------------

      // 2. Instantiate the physical Interface, passing 'clk'
      inf vif(clk);

      // 3. Instantiate the physical DUT, passing the modport
      d_flip_flop dut(vif.d_ff);

      // ---------------------------------------------------------

      // 4. THE DATABASE and RUN_TEST
      initial begin

        // We upload 'vif' into the UVM Cloud Database so the Driver can get it!
        uvm_config_db #(virtual inf)::set(null, "*", "vif", vif);

        // Start the UVM Test
        run_test("dff_test");

      end

    endmodule
