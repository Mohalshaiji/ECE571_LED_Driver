`timescale 1ns/1ps

module tb_i2c_bus_interface();

	// System clock and reset
	logic clk = 0;
	logic reset = 1;

	// I2C bus wires (shared with DUT)
	wire SDA;
	wire SCL;

    	// Testbench's control of SDA (open-drain)
	logic sda_drive;
	logic sda_drive_en;      // 1 = TB drives SDA, 0 = TB releases SDA (Z)
	logic scl_tb;

	assign SDA = sda_drive_en ? sda_drive : 1'bz;
	assign SCL = scl_tb;

    	// DUT outputs and inputs
	logic [7:0] rx_data;
	logic rx_valid;
	logic [7:0] tx_data;
	logic tx_req;
	logic tx_ready;

    	// Generate internal system clock
	always #5 clk = ~clk;

    	// Instantiate the DUT
	i2c_bus_interface dut (
		.clk(clk),
		.reset(reset),
		.SDA(SDA),
		.SCL(SCL),
		.rx_data(rx_data),
		.rx_valid(rx_valid),
		.tx_data(tx_data),
		.tx_req(tx_req),
		.tx_ready(tx_ready)
	);

	initial begin
        	// Initial conditions: I2C bus idle state
		scl_tb = 1;
		sda_drive_en = 1;
		sda_drive = 1;

        	// Release reset
		#20 reset = 0;
		$display("I2C simple test started");

        	// Test the RX path: send START → 0x55 → STOP
		$display("Sending byte 0x55 to DUT");
		send_start();
		send_byte(8'h55);
		send_stop();
		#200;

        	// Test the TX path: DUT should output 0xAA
		$display("Testing DUT transmit byte 0xAA");
		send_start();

		tx_data = 8'hAA;
		tx_req  = 1;
		#20 tx_req = 0;

        	// Release SDA so DUT can drive it
		sda_drive_en = 0;

        	// Provide clock pulses for DUT output bits
		for (int i = 0; i < 8; i++) begin
	    		#50 scl_tb = 0;
	    		#50 scl_tb = 1;
		    	$display("DUT TX bit %0d = %0b", i, SDA);
	end

		send_stop();
		#100;

		$display("Test complete");
		$finish;
	end

    	// Generate an I2C START condition: SDA falls while SCL is high	
	task send_start();
		sda_drive_en = 1;
		scl_tb = 1;
		sda_drive = 1; #40;
		sda_drive = 0; #40;
		scl_tb = 0; #40;
	endtask

    	// Generate an I2C STOP condition: SDA rises while SCL is high
	task send_stop();
		scl_tb = 1;
		sda_drive = 0; #40;
		sda_drive = 1; #40;
	endtask

    	// Send 8 bits MSB-first on SDA
	task send_byte(input [7:0] data);
		for (int i = 7; i >= 0; i--) begin
	    		sda_drive_en = 1;
	    		sda_drive = data[i]; #40;
	    		scl_tb = 1; #40;   // SCL rising → DUT samples SDA
	    		scl_tb = 0; #40;
	end
	endtask

    	// Display every received byte
	always @(posedge rx_valid)
		$display("DUT received byte: 0x%02h", rx_data);

endmodule

