// Basic PWM generator module
module pwm #(parameter WIDTH = 8) (
    output logic pwm_out,
    global_if glb,
    input  logic clk,   
    input  logic [WIDTH-1:0] duty
);

logic [WIDTH-1:0] counter;

always_ff @(posedge clk or posedge glb.reset) begin
    if (glb.reset)
        counter <= 0;
    else
        counter <= counter + 1;
end

// PWM compare logic
always_comb begin
    pwm_out = (counter < duty);
end
endmodule