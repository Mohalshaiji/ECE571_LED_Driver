// Main Module
module led_driver(
    input logic reset,
    input logic scl,
    inout wire  sda,
    output logic [3:0] leds
);
    // Intermediate Connections  
    logic       sleep;      // Sleep bit from MODE register (bit 4)
    logic       clk_osc;    // internal 400 kHz clock for LED timing

    // Interfaces
    global_if   glb(.reset, .sleep);    // Global signal interface for sleep and reset
    bus_if      bus(.clk(clk_osc));     // Data bus between I2C controller & LED controller

    // Power-on-Reset

    //-- Oscillator --
    oscillator_400K u_osc (
        .glb        (glb),
        .clk_400K   (clk_osc)
    );

    //-- LED Controller --
    led_controller u_led_ctrl(
        .leds       (leds),
        .sleep      (sleep),
        .clk_400K   (clk_osc),
        .bus        (bus.led_ctrl),
        .glb        (glb)
    );

    // From I2C bus interface → I2C controller
    logic  [7:0] i2c_byte;       // received I2C byte
    logic        i2c_byte_valid; // pulse when a new byte is available

    logic   [7:0] tx_data;       // transmiting byte on I2C bus
    logic         tx_req;        // one-cycle pulse requesting the interface to send tx_data 
    logic         tx_ready;      // indicates that the I2C interface is ready to accept a new tx_data byte
    
    // Register interface between I2C controller and LED controller
    logic [2:0] reg_addr;        // 3-bit address (0x0–0x7)
    logic [7:0] reg_wdata;       // data to write
    logic [7:0] reg_rdata;       // data read
    logic       reg_write;       // write strobe
    logic       reg_read;        // read strobe


    //-- I2C --


    // I2C bus interface module(Liukee)
    i2c_bus_interface u_i2c_bus(
        .clk        (clk_osc),
        .reset      (reset),
        .SDA        (sda),
        .SCL        (scl),

        .rx_data    (i2c_byte), 
        .rx_valid   (i2c_byte_valid),

        .tx_data    (tx_data),
        .tx_req     (tx_req),
        .tx_ready   (tx_ready)
    ）；

    // I2C controller module
endmodule
