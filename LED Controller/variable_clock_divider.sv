// Module to divide clock signals by a variable amount
module variable_clock_divider #(parameter WIDTH = 8) (
    output logic clk_out,
    global_if glb,
    input logic clk_in,
    input logic [WIDTH-1:0] divisor
);

// Counter register
logic [WIDTH-1:0] counter;

always_ff @(edge clk_in or posedge glb.reset) begin
    if (glb.reset) begin
        counter <= 0;
        clk_out <= 0;
    end else begin
        if (counter == divisor) begin
            counter <= 0;
            clk_out <= ~clk_out;   // Toggle output
        end else begin
            counter <= counter + 1;
        end
    end
end

endmodule