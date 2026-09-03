import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------------------------
    // 1. CLASS DECLARATION
    // -------------------------------------------------------------------------
    // We extend the built-in uvm_driver and specify our custom transaction
    class apb_driver extends uvm_driver #(apb_transaction);

      // Register as a permanent COMPONENT in the UVM Factory
      `uvm_component_utils(apb_driver)

      // -----------------------------------------------------------------------
      // 2. THE VIRTUAL INTERFACE (The Remote Control)
      // -----------------------------------------------------------------------
      // The Driver needs a software pointer to touch the physical hardware wires.
      // We use '.tb' to force the driver to obey the clocking block rules.
    virtual apb_i2c_if vif;
      // -----------------------------------------------------------------------
      // 3. CONSTRUCTOR
      // -----------------------------------------------------------------------
      function new(string name = "apb_driver", uvm_component parent);
        super.new(name, parent);
      endfunction

      // -----------------------------------------------------------------------
      // 4. BUILD PHASE (Getting the Remote Control)
      // -----------------------------------------------------------------------
      // Before time 0, we reach into the UVM Config DB to get the virtual interface.
      function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // "Get the interface named 'vif' and put it in my variable 'vif'"
    if (!uvm_config_db#(virtual apb_i2c_if)::get(this, "", "vif", vif)) begin       
        `uvm_fatal("DRV", "Failed to get virtual interface from config_db!")
        end
      endfunction

      // -----------------------------------------------------------------------
      // 5. RUN PHASE (The Eternal Loop & APB Logic)
      // -----------------------------------------------------------------------
      // This consumes time and runs forever, processing one transaction at a time.
      task run_phase(uvm_phase phase);

        // 1. Initialize APB control pins to 0 (Idle state)
        vif.cb.PSEL    <= 1'b0;
        vif.cb.PENABLE <= 1'b0;

        // 2. The endless loop
        forever begin

          // -------------------------------------------------------------------
          // STEP A: WAIT FOR THE TRANSACTION
          // -------------------------------------------------------------------
          // Built-in UVM keyword: Stop time and wait for the Sequencer to hand us 'req'
          seq_item_port.get_next_item(req);

          // -------------------------------------------------------------------
          // STEP B: DRIVE THE APB BUS (Your Hardware Logic)
          // -------------------------------------------------------------------

          // Wait for the next clock edge so everything is synchronized
          @(vif.cb);

          // --- APB SETUP PHASE ---
          // Put Address and Write/Read command on the bus
          vif.cb.PADDR  <= req.PADDR;
          vif.cb.PWRITE <= req.PWRITE;

          // If the transaction is a Write, put the data on the bus
          if (req.PWRITE) begin
            vif.cb.PWDATA <= req.PWDATA;
          end

          // Assert PSEL to start the transfer. Keep PENABLE low.
          vif.cb.PSEL    <= 1'b1;
          vif.cb.PENABLE <= 1'b0;

          // --- APB ACCESS PHASE ---
          // Wait for the very next clock edge
          @(vif.cb);

          // Assert PENABLE to execute the transfer
          vif.cb.PENABLE <= 1'b1;

          // --- APB WAIT STATES ---
          // Keep waiting clock cycles as long as PREADY is NOT 1 (DUT is busy).
          // (Even though your DUT ties PREADY to 1, this makes the code professional)
          do begin
            @(vif.cb);
          end while (vif.cb.PREADY !== 1'b1);

          // --- READ CAPTURE ---
          // If this was a Read command, the DUT has put the answer on the wires.
          // Capture the physical wire value and save it back into the software transaction.
          if (!req.PWRITE) begin
            req.PRDATA = vif.cb.PRDATA;
          end

          // --- APB IDLE PHASE (Cleanup) ---
          // Drop PSEL and PENABLE back to 0 to end the transfer.
          vif.cb.PSEL    <= 1'b0;
          vif.cb.PENABLE <= 1'b0;

          // Print a debug message saying the transfer is complete
          `uvm_info("DRV", $sformatf("Finished driving APB transfer to Address: %0h", req.PADDR), UVM_HIGH)

          // -------------------------------------------------------------------
          // STEP C: TELL SEQUENCER WE ARE DONE
          // -------------------------------------------------------------------
          // Built-in UVM keyword: Handshake with Sequencer to get the next item
          seq_item_port.item_done();

        end // End of forever loop
      endtask

    endclass
