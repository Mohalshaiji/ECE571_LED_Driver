// Main Module
module led_driver(
    input logic reset,
    input logic scl,
    inout wire  sda,
    output logic [3:0] leds
);

// Power-on-Reset

// oscillator
module led_driver(
    input logic reset,
    input logic scl,
    inout wire  sda,
    output logic [3:0] leds
);

// Power-on-Reset

// oscillator
    logic clk_osc;  // internal 400 kHz clock for LED timing

    // oscillator module
    oscillator_400K u_osc (
        .glb      (glb),
        .clk_400K (clk_osc)
    );

// led_controller
    
    // From I2C bus interface → I2C controller
    logic  [7:0] i2c_byte;       // received I2C byte
    logic        i2c_byte_valid; // pulse when new byte is available

    // Register interface between I2C controller and LED controller
    logic [2:0] reg_addr;        // 3-bit address (0x0–0x7)
    logic [7:0] reg_wdata;       // data to write
    logic [7:0] reg_rdata;       // data read
    logic       reg_write;       // write strobe
    logic       reg_read;        // read strobe

    // Sleep bit from MODE register (bit 4)
    logic       sleep;

// i2c instantiation

endmodule
