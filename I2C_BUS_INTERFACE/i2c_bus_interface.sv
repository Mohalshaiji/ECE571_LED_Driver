//I2C bit-level interface 
//LIUKEE

`timescale 1ns/1ps

module i2c_bus_interface (
	input  logic clk, // System clock (> I2C SCL)
	input  logic reset,// Active-high reset
	inout  wire  SDA, // I2C data line (open-drain)
	input  logic SCL, // I2C clock line
	// Receive interface to I2C controller(to Mohammad's controller)
	output logic [7:0] rx_data,  // Received byte
	output logic rx_valid, // Pulse when byte is ready
    output logic start_o,
    output logic stop_o,

	// Transmit interface (from controller)
	input  logic [7:0] tx_data,  // Byte to send
	input  logic tx_req,   // Pulse: request to send
    output logic tx_ready  // Ready for next byte
);	
//Edge detection(synchronized)
	logic scl_prev, sda_prev;

	always_ff @(posedge clk or posedge reset) begin
	       	if (reset) begin
			scl_prev <= 1'b1;   // assume bus idle
			sda_prev <= 1'b1;
		end else begin
			scl_prev <= SCL;
			sda_prev <= SDA;
		end
	end
	
	wire scl_rising  = (SCL && !scl_prev);
	wire scl_falling = (!SCL && scl_prev);
	
	// START & STOP
	wire start_cond = (SCL && sda_prev && !SDA); // SDA: 1->0 while SCL=1
	wire stop_cond  = (SCL && !sda_prev && SDA); // SDA: 0->1 while SCL=1

        //START & STOP OUTPUT
        assign start_o = start_cond;
        assign stop_o  = stop_cond;


// RECEIVE LOGIC (serial → parallel)

	logic [7:0] shift_reg;
	logic [2:0] bit_count;
	logic receiving;

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			receiving <= 0;
			shift_reg <= 0;
			bit_count <= 0;
			rx_valid <= 0;
			rx_data <= 0;
		end else begin
			rx_valid <= 0;
		if (start_cond) begin
			receiving <= 1;
			bit_count <= 0;
		end
		else if (stop_cond) begin
			receiving <= 0;
		end
		else if (receiving && scl_rising) begin
			shift_reg <= {shift_reg[6:0], SDA};

		if (bit_count == 7) begin
			rx_data  <= {shift_reg[6:0], SDA};
			rx_valid <= 1;     // byte ready
			bit_count <= 0;
		end else begin
			bit_count <= bit_count + 1;
			end
		end
	end
end

// TRANSMIT LOGIC (parallel → serial)
	logic [7:0] tx_shift;
	logic [2:0] tx_bit_cnt;
	logic       sending;

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			sending <= 0;
			tx_ready <= 1;
		end else begin
		if (tx_req && tx_ready) begin
			tx_shift <= tx_data;
			tx_bit_cnt <= 0;
			sending <= 1;
			tx_ready <= 0;
		end
		else if (sending && scl_falling) begin
			if (tx_bit_cnt == 7) begin
				sending <= 0;
				tx_ready <= 1;
		end else begin
			tx_bit_cnt <= tx_bit_cnt + 1;
		end
	end

	if (stop_cond) begin
		sending <= 0;
		tx_ready <= 1;
	end
end
end

// SDA TRI-STATE (open-drain)
//Testbench master must release SDA when sending == 1
	assign SDA = sending ? tx_shift[7 - tx_bit_cnt] : 1'bz;

endmodule
