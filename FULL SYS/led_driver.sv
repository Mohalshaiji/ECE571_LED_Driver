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
    logic greset;         // global reset used inside design
    logic por_reset;      // one-cycle POR pulse

    assign greset = reset | por_reset;  // external reset OR power-on pulse

    // Interfaces
    global_if   glb(.greset, .sleep);    // Global signal interface for sleep and reset
    bus_if      bus(.clk(clk_osc));     // Data bus between I2C controller & LED controller

    // Power-on-Reset
    por_one_cycle u_por (
        .clk       (clk_osc),
        .reset_out (por_reset)
    );
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

    // Register interface between I2C controller and LED controller
    logic [2:0] reg_addr;        // 3-bit address (0x0–0x7)
    logic [7:0] reg_wdata;       // data to write
    logic [7:0] reg_rdata;       // data read
    logic       reg_write;       // write strobe
    logic       reg_read;        // read strobe


    // I2C TX-side signals between controller and interface
    logic [7:0] i2c_tx_data;      // byte to send to master
    logic       i2c_tx_req;       // request to send
    logic       i2c_tx_ready;     // bit-level ready

    // START/STOP from I2C interface to controller
    logic       i2c_start;
    logic       i2c_stop;

    logic       i2c_transaction_done;

    //-- I2C --

    //I2C interface
    i2c_bus_interface u_i2c_bus (
        .clk      (clk_osc),        // system clock (> SCL)
        .reset    (reset),          // active-high reset
        .SDA      (sda),            // I2C data line
        .SCL      (scl),            // I2C clock line

        // Receive side to controller
        .rx_data  (i2c_byte),
        .rx_valid (i2c_byte_valid),

        // Transmit side from controller
        .tx_data  (i2c_tx_data),
        .tx_req   (i2c_tx_req),
        .tx_ready (i2c_tx_ready),

        // Exposed START/STOP conditions
        .start    (i2c_start),
        .stop     (i2c_stop)
    );

    // Byte-level I2C controller 
    i2c_controller #(
        .DEVICE_ADDR(7'h40)         // I2C 7-bit slave address
    ) u_i2c_ctrl (
        .clk              (clk_osc),
        .g_if             (glb),
        .bus              (bus.i2c_ctrl),

        // From interface
        .start            (i2c_start),
        .stop             (i2c_stop),
        .rx_valid         (i2c_byte_valid),
        .rx_data          (i2c_byte),

        // To interface for reads
        .tx_data          (i2c_tx_data),
        .tx_req           (i2c_tx_req),
        .tx_ready         (i2c_tx_ready),

        .transaction_done (i2c_transaction_done)
    );

    //expose bus_if activity onto the reg_* signals for debug
    assign reg_addr  = bus.addr;
    assign reg_wdata = bus.data;   // valid when reg_write is high
    assign reg_write = bus.w_en;
    assign reg_read  = bus.r_en;
    assign reg_rdata = bus.data;   // valid when reg_read is high
endmodule
