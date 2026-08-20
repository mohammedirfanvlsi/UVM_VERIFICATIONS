interface inf (input logic clk);

      logic d;
      logic q;
      logic rst_n;

      clocking cb @(posedge clk);
        default input #1 output #0;
        output d, rst_n;
        input q;
      endclocking

      modport d_ff(input d, clk, rst_n, output q);
      modport tb(clocking cb);

      // --- Properties ---
      property rst;
        @(posedge clk)
        (!rst_n) |-> (q == 1'b0);
      endproperty

      property d_to_q;
        @(posedge clk)
        disable iff(!rst_n)
        (1'b1) |-> (q == $past(d)); // Fixed the operator to |->
      endproperty

      // --- Assertions ---
      // Ensure the property names match the definitions above
      assert_reset: assert property (rst)
        else $error("[%0t] FAIL: Q is not 0 during reset!", $time);

      assert_d_to_q: assert property (d_to_q)
        else $error("[%0t] FAIL: Q did not follow D!", $time);

    endinterface
