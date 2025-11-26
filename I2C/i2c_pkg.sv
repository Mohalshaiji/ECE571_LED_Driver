package i2c_pkg;

  parameter int I2C_ADDR_WIDTH = 7; // I2C device address width
  parameter int I2C_DATA_WIDTH = 8; // I2C data width
  parameter int REG_ADDR_WIDTH = 8; // Register address width in bytes

  typedef enum logic [1:0] {
    CTRL_IDLE,
    CTRL_ADDR,
    CTRL_REG,
    CTRL_DATA
  } ctrl_state_t; // States of the I2C controller

  typedef struct packed {
    logic [REG_ADDR_WIDTH-1:0] addr;
    logic [I2C_DATA_WIDTH-1:0] data;
    logic                      write_en;
    logic                      read_en;
  } reg_bus_t; // Simple register bus used between controller and LED logic

endpackage : i2c_pkg
