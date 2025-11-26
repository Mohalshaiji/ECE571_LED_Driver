// Global package for the project
package led_driver_pkg;
    parameter ADDR_BITS = 3;
    parameter DATA_BITS = 8;
    parameter I2C_ADDR_BITS = 7; 
    
    // Enumeration for the function of each register
    typedef enum logic [ADDR_BITS-1:0] { 
        REG_MODE = 0,
        REG_PWM0,
        REG_PWM1,
        REG_PWM2,
        REG_PWM3,
        REG_GRPPWM,
        REG_GRPFREQ,
        REG_LEDOUT
    } reg_enum_t;

    // Structure to define the bitfields of REG_MODE
    typedef struct packed {
        logic [2:0] auto_increment;
        logic sleep;
        logic dim_blink;
        logic invert;
        logic output_change;
        logic reserved;
    } reg_mode_t;

    // Enumeration of the possible LED output states
    typedef enum logic [1:0] {
        LED_OFF = 0,
        LED_ON,
        LED_INDIVIDUAL,
        LED_GROUP
    } led_out_enum_t;

    // Structure to define the bitfields of REG_LEDOUT
    typedef struct packed {
        led_out_enum_t LED3;
        led_out_enum_t LED2;
        led_out_enum_t LED1;
        led_out_enum_t LED0;
    } reg_led_out_t;

endpackage
    // Enumeration of I2C control states
    typedef enum logic [1:0] {
        CTRL_IDLE,
        CTRL_ADDR,
        CTRL_REG,
        CTRL_DATA
    } ctrl_state_t;

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
