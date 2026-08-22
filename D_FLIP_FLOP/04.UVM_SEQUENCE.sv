import uvm_pkg::*;
`include "uvm_macros.svh"

class dff_sequence extends uvm_sequence #(dff_sequence_item);
 

      `uvm_object_utils(dff_sequence)

      function new(string name = "dff_sequence");
        super.new(name);
      endfunction

      task body();

        // Explicitly declaring our packet handle
        dff_sequence_item item;

        repeat(10) begin

          // The `uvm_do macro automatically does ALL of this for you:
          // 1. item = dff_sequence_item::type_id::create("item")
          // 2. start_item(item)
          // 3. item.randomize()  <-- It also automatically throws an error if this fails!
          // 4. finish_item(item)

          `uvm_do(item)

        end

        `uvm_info("SEQ", "Finished generating 10 packets using uvm_do!", UVM_LOW)

      endtask

    endclass
