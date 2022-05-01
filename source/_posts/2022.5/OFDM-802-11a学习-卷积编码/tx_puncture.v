// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_puncture
// Create 	 : 2022-04-16
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : tx punvture, 3/4 code  encoder rate
// 			   
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tx_puncture (
	input 	wire  			clk_Modulation	,
	input 	wire  			reset 			,
	input 	wire  	[1:0]	tx_ConvCodeRate	,
	input 	wire  			tx_conv_valid	,
	input 	wire  	[1:0]	tx_conv_bit 	,

	output 	reg  			tx_puncture_valid	,
	output 	reg  			tx_puncture_bit 	,
	output 	wire  			tx_puncture_bit_cnt_valid	,
	output 	wire  	[15:0]	tx_puncture_bit_cnt	
);


	reg  		fifo_rd_en 	;
	wire [1:0]	fifo_dout 	;
	reg  [1:0]	fifo_dout_dly ;
	wire  		full,empty	;

	reg  		puncture_flag 	;
	reg  [3:0]	cnt_puncture	;
	reg  		tx_puncture_valid_dly;
	wire  		tx_puncture_valid_neg_pls;
	reg [19:0]	cnt_bit 		;

	fifo_generator_tx_puncture u_fifo_generator_tx_puncture (
		.clk(clk_Modulation),     // input wire clk
		.srst(reset),    			// input wire srst
		.din(tx_conv_bit),      	// input wire [1 : 0] din
		.wr_en(tx_conv_valid),  	// input wire wr_en
		.rd_en(fifo_rd_en),  // input wire rd_en
		.dout(fifo_dout),    // output wire [1 : 0] dout
		.full(full),    // output wire full
		.empty(empty)  // output wire empty
	);
	//----------------puncture_flag------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			puncture_flag <= 1'b0;
		end
		else if(empty == 1'b0)begin
			puncture_flag <= 1'b1;
		end
		else begin
			puncture_flag <= 1'b0;
		end
	end

	//----------------cnt_puncture------------------
	// the ofdm symbole is 216bit, so there is no doubt that 
	// when the valid bit is finished, the counter will go back to zero: 0000000123,0123....0123000000
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_puncture <= 'd0;
		end
		else if(puncture_flag == 1'b1)begin
			if(cnt_puncture == 'd3)begin
				cnt_puncture <= 'd0;
			end
			else begin
				cnt_puncture <= cnt_puncture + 1'b1;
			end
		end
		else begin
			cnt_puncture <= 'd0;
		end
	end

	always @(*) begin
		if(empty==1'b0 && puncture_flag == 1'b1)begin
			case(cnt_puncture)
				0: fifo_rd_en = 1'b1;
				1: fifo_rd_en = 1'b0;
				2: fifo_rd_en = 1'b1;
				3: fifo_rd_en = 1'b1;
				default : fifo_rd_en = 1'b0;
			endcase
		end
		else begin
			fifo_rd_en = 1'b0;
		end
	end

	always @(posedge clk_Modulation) begin
		fifo_dout_dly <= fifo_dout;
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_puncture_bit <= 1'b0;
		end
		else if(empty==1'b0 && puncture_flag == 1'b1)begin
			case(cnt_puncture)
				0: tx_puncture_bit <= fifo_dout[1];
				1: tx_puncture_bit <= fifo_dout_dly[0];
				2: tx_puncture_bit <= fifo_dout[1];
				3: tx_puncture_bit <= fifo_dout[0];
				default: tx_puncture_bit <= 1'b0;
			endcase
		end
		else begin
			tx_puncture_bit <= 1'b0;
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_puncture_valid <= 1'b0;
		end
		else if(empty==1'b0 && puncture_flag == 1'b1)begin
			tx_puncture_valid <= 1'b1;
		end
		else begin
			tx_puncture_valid <= 1'b0;
		end
	end

	always @(posedge clk_Modulation) begin
		tx_puncture_valid_dly <= tx_puncture_valid;
	end
	assign tx_puncture_valid_neg_pls = (tx_puncture_valid_dly)&(~tx_puncture_valid);

	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			cnt_bit <= 'd0;
		end
		else if(tx_puncture_valid == 1'b1)begin
			cnt_bit <= cnt_bit + 1'b1;
		end
		else begin
			cnt_bit <= 'd0;
		end
	end

	assign tx_puncture_bit_cnt_valid = tx_puncture_valid_neg_pls;
	assign tx_puncture_bit_cnt = cnt_bit>>1;


endmodule