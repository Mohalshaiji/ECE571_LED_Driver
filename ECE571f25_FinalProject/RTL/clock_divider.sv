// Module to divide clock signals by a given power of 2 amount
module clock_divider #(parameter integer POW2_DIVIDE_BY = 1) (
    output logic clk_out,
    global_if glb,
    input logic clk_in
);

logic [POW2_DIVIDE_BY-1:0] count;

always_ff @(edge clk_in or posedge glb.reset) begin
    if (glb.reset) begin
        count <= 0;
        clk_out <= 0;
    end else begin
        if (count == 0)
            clk_out <= ~clk_out;
        count <= count + 1;
    end
end

endmodule