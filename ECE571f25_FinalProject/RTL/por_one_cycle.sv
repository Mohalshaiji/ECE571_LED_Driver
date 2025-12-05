module por_one_cycle (
    input  logic clk,
    output logic reset_out
);
    logic signal = 1'b1;

    always_ff @(posedge clk) begin
        signal <= 1'b0;
    end

    assign reset_out = signal;
endmodule