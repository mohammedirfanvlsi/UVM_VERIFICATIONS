`include "Interface.sv"

  module d_flip_flop(inf.d_ff bus);

      // Use bus.clk and bus.rst_n in the sensitivity list
      always_ff @(posedge bus.clk or negedge bus.rst_n) begin

        if(!bus.rst_n)
          bus.q <= 1'b0;
        else
          bus.q <= bus.d;

      end
    endmodule
