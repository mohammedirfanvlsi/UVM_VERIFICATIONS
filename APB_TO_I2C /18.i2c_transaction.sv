import uvm_pkg::*;
    `include "uvm_macros.svh"

class i2c_transaction extends uvm_sequence_item;

      // This holds the 8 bits of data we captured from the physical I2C wires
      logic [7:0] i2c_data;

      // Standard UVM Factory Registration
      `uvm_object_utils_begin(i2c_transaction)
        `uvm_field_int(i2c_data, UVM_ALL_ON)
      `uvm_object_utils_end

      function new(string name = "i2c_transaction");
        super.new(name);
      endfunction

    endclass
