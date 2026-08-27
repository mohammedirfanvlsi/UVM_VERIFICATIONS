 import uvm_pkg::*;
    `include "uvm_macros.svh"

    // FIXED: Passed the transaction type into the subscriber parameter
    class apb_coverage extends uvm_subscriber #(apb_transaction);

      `uvm_component_utils(apb_coverage)

      // NOTE: We deleted the manual analysis_imp! uvm_subscriber creates
      // one for you automatically called 'analysis_export'.

      // FIXED: Declare a class-level handle so the covergroup can see the data!
      apb_transaction m_req;

      // -----------------------------------------------------------------------
      // COVERGROUP DEFINITION
      // -----------------------------------------------------------------------
      covergroup apb_cov;

        // FIXED: Typo (underscore instead of dot)
        option.per_instance = 1;

        // Check if we hit all 5 of our bridge registers!
        coverpoint m_req.PADDR {
          // FIXED: Added [] to create 5 independent bins.
          bins address[] = {32'h0, 32'h1, 32'h2, 32'h3, 32'h4};
        }

        // Check what kind of data is flowing through
        coverpoint m_req.PWDATA;

      endgroup

      // -----------------------------------------------------------------------
      // CONSTRUCTOR
      // -----------------------------------------------------------------------
      function new(string name = "apb_coverage", uvm_component parent);
        super.new(name, parent);
        apb_cov = new(); // Build the covergroup in memory
      endfunction

      // -----------------------------------------------------------------------
      // WRITE FUNCTION (Triggered by the Monitor)
      // -----------------------------------------------------------------------
      // Note: uvm_subscriber forces us to name the argument 't' by default
      virtual function void write(apb_transaction t);
        // 1. Copy the incoming packet 't' into our class variable 'm_req'
        m_req = t;

        // 2. Tell the covergroup to take a picture of m_req!
        apb_cov.sample();
      endfunction

      // -----------------------------------------------------------------------
      // REPORT PHASE (Runs at the very end of the simulation)
      // -----------------------------------------------------------------------
      virtual function void report_phase(uvm_phase phase);
        // FIXED: Typos in sformatf and %0.2f
        // Note: We don't print PADDR or PWDATA here, because this phase runs
        // at the very end, so it would only print the very last packet's data!
        `uvm_info("COVERAGE", $sformatf("THE FINAL COVERAGE = %0.2f %%", apb_cov.get_inst_coverage()), UVM_NONE)
      endfunction

    endclass
