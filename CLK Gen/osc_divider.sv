// ------------------------------------------------------------
// osc_divider.sv
// Divide on-chip oscillator down to ~6.25 kHz and ~1.56 kHz
// ------------------------------------------------------------
`timescale 1ns/1ps

module osc_divider (
    input  logic clk_osc,     // e.g. 400 kHz simulated oscillator
    input  logic rst_n,       // active-low synchronous reset
    output logic clk_6k25,    // ~ clk_osc / 64
    output logic clk_1k56     // ~ clk_osc / 256
);

    // Simple free-running counter
    logic [7:0] div_cnt;

    always_ff @(posedge clk_osc or negedge rst_n) begin
        if (!rst_n)
            div_cnt <= '0;
        else
            div_cnt <= div_cnt + 8'd1;
    end

    // Tap bits to form divided clocks
    // If clk_osc = 400 kHz:
    //   bit 5 -> 400k / 2^6  = 6.25 kHz
    //   bit 7 -> 400k / 2^8  = 1.5625 kHz
    assign clk_6k25 = div_cnt[5];
    assign clk_1k56 = div_cnt[7];

endmodule
