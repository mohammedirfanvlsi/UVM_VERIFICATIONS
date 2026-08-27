// ===========================================================================
    // UVM INTERFACE: APB to I2C Bridge
    // ===========================================================================

    // 1. INTERFACE DECLARATION
    // We pass the official APB clock (PCLK) as an input so the whole testbench
    // uses the exact same clock.
    interface apb_i2c_if (input logic PCLK);

      // -----------------------------------------------------------------------
      // 2. SYSTEM RESET
      // -----------------------------------------------------------------------
      // The testbench will drive this. 'n' means it is Active-Low (0 = Reset).
      logic PRESETn;

      // -----------------------------------------------------------------------
      // 3. APB BUS SIGNALS (Master -> Slave)
      // -----------------------------------------------------------------------
      // These are declared as 'logic' because only ONE thing drives them (The Master).
      logic [31:0] PADDR;   // The memory address we want to write to or read from
      logic        PSEL;    // Chip Select: '1' tells the Bridge "I am talking to you"
      logic        PENABLE; // Enable: '1' means the data is ready to be transferred
      logic        PWRITE;  // Write/Read control: '1' = Write, '0' = Read
      logic [31:0] PWDATA;  // The actual 32-bit data being sent to the Bridge

      // -----------------------------------------------------------------------
      // 4. APB BUS SIGNALS (Slave -> Master)
      // -----------------------------------------------------------------------
      logic [31:0] PRDATA;  // The 32-bit data coming back from the Bridge to the CPU
      logic        PREADY;  // Ready flag: '1' tells the CPU "I finished the transfer"

      // -----------------------------------------------------------------------
      // 5. I2C PHYSICAL PINS (Bidirectional)
      // -----------------------------------------------------------------------
      // CRITICAL: These MUST be 'wire'. If they are 'logic', you will get a
      // "multi-driver error" because both the Bridge and the Slave drive them.
      wire scl;  // I2C Clock Pin
      wire sda;  // I2C Data Pin

      // -----------------------------------------------------------------------
      // 6. CLOCKING BLOCK (For UVM Timing)
      // -----------------------------------------------------------------------
      // Why do we need this? To prevent "Race Conditions". It makes sure the
      // testbench doesn't push data at the EXACT same picosecond the DUT reads it.
      clocking cb @(posedge PCLK);

        // OUTPUTS are pushed instantly (0ns) at the clock edge.
        // INPUTS are sampled right before (1ns) the clock edge to get stable data.
        default input #1 output #0;

        // What the Testbench READS from the DUT:
        input  PRDATA, PREADY;
        input  sda, scl;

        // What the Testbench SENDS to the DUT:
        output PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA;

      endclocking

      // -----------------------------------------------------------------------
      // 7. MODPORTS (Access Rules)
      // -----------------------------------------------------------------------
      // Modports act like security guards. They tell each module what they
      // are allowed to see and do.

      // The DUT (Your Bridge) connects directly to the raw wires.
      modport dut (
        input  PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA,
        output PRDATA, PREADY,
        inout  sda, scl
      );

      // The UVM Testbench is ONLY allowed to connect through the clocking block ('cb')
      // This forces the testbench to obey the strict timing rules we set above.
      modport tb (clocking cb);

      // =======================================================================
      // 8. SYSTEM VERILOG ASSERTIONS (Automatic Error Checkers)
      // =======================================================================

      // A. Check Reset Behavior
      // PLAIN ENGLISH: "When Reset is 0, the Read Data must immediately become 0."
      property p_reset_check;
        @(posedge PCLK)
        (!PRESETn) |-> (PRDATA == 0);
      endproperty

      // B. Check APB Phase Transition
      // PLAIN ENGLISH: "If APB is in the Setup Phase (PSEL=1, PENABLE=0), then
      // in the VERY NEXT cycle (|=>), it must move to the Access Phase (PENABLE=1)."
      property p_apb_phase_transition;
        @(posedge PCLK)
        disable iff(!PRESETn) // Ignore this rule if we are currently in Reset
        (PSEL == 1 && PENABLE == 0) |=> (PENABLE == 1);
      endproperty

      // C. Check APB Signal Stability
      // PLAIN ENGLISH: "When moving from Setup Phase to Access Phase (next cycle),
      // the Address, Write flag, and PSEL must NOT change ($stable)."
      property p_apb_stable_ctrl;
        @(posedge PCLK)
        disable iff(!PRESETn)
        (PSEL == 1 && PENABLE == 0) |=> ($stable(PADDR) && $stable(PWRITE) && $stable(PSEL));
      endproperty

      // D. Check I2C Golden Rule
      // PLAIN ENGLISH: "If SCL is High, the SDA wire must NOT change state."
      property p_i2c_sda_stable;
        @(posedge PCLK)
        disable iff(!PRESETn)
        (scl == 1'b1) |-> $stable(sda);
      endproperty

      // -----------------------------------------------------------------------
      // 9. TURN ON THE ASSERTIONS
      // -----------------------------------------------------------------------
      // If any property fails during simulation, print a fatal error to the console.
      assert property (p_reset_check)          else $error("BUG: Reset failed!");
      assert property (p_apb_phase_transition) else $error("BUG: APB PENABLE did not go High!");
      assert property (p_apb_stable_ctrl)      else $error("BUG: APB Controls changed during transfer!");
      // assert property (p_i2c_sda_stable)    else $warning("BUG: I2C SDA changed while SCL was High!");

    endinterface
