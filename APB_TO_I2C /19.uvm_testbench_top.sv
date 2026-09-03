
     // =========================================================================
    // 1. UVM IMPORTS & MACROS
    // =========================================================================
    // We must load the UVM C-like library into memory first, otherwise the
    // simulator won't know what "uvm_test" or "run_test" means!
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // =========================================================================
    // 2. HARDWARE INCLUDES (These MUST be here before module top!)
    // =========================================================================
    // We tell the compiler to read our physical hardware blueprints here.
    // They must be read first so the 'top' module knows what they are.
    `include "Interface.sv"
    `include "i2c_slave.sv"

    // =========================================================================
    // 3. UVM CLASS INCLUDES (Fixes the Factory Error!)
    // =========================================================================
    // We MUST include our UVM files here! If we don't, the simulator will
    // skip them, and when run_test("apb_test") looks for the test in the
    // factory, it will crash because it was never compiled!
    // (Order matters: lowest level classes first, highest level test last).
    `include "uvm_sequence_item.sv"
    `include "i2c_transaction.sv"
    `include "uvm_sequence.sv"
    `include "uvm_sequencer.sv"
    `include "uvm_driver.sv"
    `include "uvm_monitor.sv"
    `include "uvm_agent.sv"
     `include "i2c_monitor.sv"
    `include "uvm_scoreboard.sv"
    `include "uvm_coverage.sv"
    `include "uvm_environment.sv"
    `include "uvm_test.sv"

    // =========================================================================
    // 4. TOP MODULE (The Physical Hardware Workbench)
    // =========================================================================
    module top;

      // This is the main heartbeat wire for the entire system
      logic PCLK;

      // -----------------------------------------------------
      // A. Create the physical wires
      // -----------------------------------------------------
      // Imagine laying a bundle of copper wires onto your workbench.
      // 'apb_i2c_if' is the blueprint. 'vif' is the actual physical wire bundle.
      apb_i2c_if vif(PCLK);

      // -----------------------------------------------------
      // B. Instantiate the Design Under Test (APB to I2C Bridge)
      // -----------------------------------------------------
      // We place the main chip (DUT) onto the workbench and plug it into
      // our bundle of copper wires using '.bus(vif.dut)'.
      apb_i2c_core dut(
          .bus(vif.dut)
      );

      // -----------------------------------------------------
      // C. Instantiate the I2C Slave
      // -----------------------------------------------------
      // We place the destination chip (EEPROM/Slave) onto the workbench.
      // We wire its 'scl' and 'sda' pins directly to the exact same bundle
      // of copper wires so the DUT and Slave can talk to each other.
      i2c_slave my_slave (
          .scl(vif.scl),
          .sda(vif.sda),

          // The slave needs a clock and reset to function, so we wire them up!
          .clk(PCLK),
          .rst_n(vif.PRESETn),

          // We tie 'data_in' to 0, and leave the outputs empty so the
          // simulator doesn't throw "unconnected pin" warnings.
          .data_in(8'h00),
          .data_out(),
          .data_valid()
      );

      // -----------------------------------------------------
      // D. I2C Pull-Up Resistors
      // -----------------------------------------------------
      // The I2C protocol is "Open-Drain". This means chips can only pull the
      // wire down to 0. If nobody is talking, the wire MUST default to 1.
      // 'pullup' attaches a physical resistor to the wire to force it to 1.
      // Without this, the wires float at 'X' (Unknown) and the chips crash!
      pullup(vif.scl);
      pullup(vif.sda);

      // -----------------------------------------------------
      // E. Hardware Clocks and Resets
      // -----------------------------------------------------
      // The forever loop creates a 100 MHz heartbeat for the system hardware.
      initial begin
        PCLK = 0;
        forever #5 PCLK = ~PCLK;
      end

      // This wakes up the hardware. We pull reset to 0, wait for 2 clock
      // cycles to ensure the chips are totally cleared, then flip it to 1 to start!
      initial begin
        vif.PRESETn = 0;
        @(vif.cb);
        @(vif.cb);
        vif.PRESETn = 1;
      end

      // -----------------------------------------------------
      // F. UVM Config DB and Run Test (The Software Bridge)
      // -----------------------------------------------------
      initial begin
        // THE UPLOAD: We take our physical copper wires ('vif') and upload
        // them into the UVM Cloud Database. Later, our UVM Driver will download
        // them so it can physically wiggle the pins!
        // (We use 'uvm_pkg::' explicitly to bypass a Cadence compiler bug!)
        uvm_pkg::uvm_config_db #(virtual apb_i2c_if)::set(null, "*", "vif", vif);

        // THE BOOT SEQUENCE: This command boots up the UVM software engine.
        // It searches the factory for "apb_test", builds it in memory, and
        // automatically starts running your APB Sequence!
        run_test("apb_test");
      end

    endmodule
