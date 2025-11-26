// Global package for the project
package led_driver_pkg;
    parameter ADDR_BITS = 3;
    parameter DATA_BITS = 8;
    
    // Enumeration for the function of each register
    typedef enum logic [ADDR_BITS-1:0] { 
        REG_MODE = 0,   // Mode select bits (see reg_mode_t)
        REG_PWM0,       // PWM duty cycle for LED0
        REG_PWM1,       // PWM duty cycle for LED1
        REG_PWM2,       // PWM duty cycle for LED2
        REG_PWM3,       // PWM duty cycle for LED3
        REG_GRPPWM,     // Group PWM duty cycle (dim=190Hz, blink=24-0.9Hz)
        REG_GRPFREQ,    // Group frequency (only used for blink mode, selects 24-0.9Hz frequency)
        REG_LEDOUT      // Output mode select bits for each LED (see led_out_enum_t & reg_led_out_t)
    } reg_enum_t;

    // Structure to define the bitfields of REG_MODE
    typedef struct packed {
        logic [2:0] auto_increment; // Auto-Increment control (may be unused)
        logic sleep;                // Sleep mode: 0=normal, 1=low-power
        logic dim_blink;            // Group mode: 0=dim, 1=blink
        logic invert;               // Output Inversion: 0=normal, 1=inverted
        logic output_change;        // Output update trigger (from I2C bus): 0=STOP, 1=ACK
        logic reserved;             // Reserved
    } reg_mode_t;

    // Enumeration of the possible LED output states
    typedef enum logic [1:0] {
        LED_OFF = 0,    // LED is off
        LED_ON,         // LED is fully on (no PWM)
        LED_INDIVIDUAL, // LED uses the duty cycle from PWMx at 1.5625KHz
        LED_GROUP       // LED uses the group duty cycle and frequency
    } led_out_enum_t;

    // Structure to define the bitfields of REG_LEDOUT
    typedef struct packed {
        led_out_enum_t LED3;
        led_out_enum_t LED2;
        led_out_enum_t LED1;
        led_out_enum_t LED0;
    } reg_led_out_t;

endpackage

// Interface to connect the LED & I2C control modules
interface bus_if (input logic clk);
    import led_driver_pkg::*;
    wire [DATA_BITS-1:0] data;
    logic [ADDR_BITS-1:0] addr;
    logic r_en, w_en;

    modport i2c_ctrl(output addr, r_en, w_en, inout data);
    modport led_ctrl(input addr, r_en, w_en, inout data);
endinterface

// Global interface containing the reset and sleep signals (Should be used in every module!!)
interface global_if(input logic reset, input logic sleep); endinterface