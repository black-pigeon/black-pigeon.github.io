// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_gen_pkt_sig
// Create 	 : 2022-04-22
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : ofdm signal domain data generator
// 			   
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tx_gen_pkt_sig(
	input 	wire		clk_Modulation			,
	input 	wire		reset					,
	input 	wire [5:0]	tx_Rate					,
	input	wire		preamble_ready			,
	input 	wire [15:0]	packetlength			,
	output 	reg 		tx_gen_pkt_sig_valid	,
	output 	wire 		tx_gen_pkt_sig_out
);


	reg 	[3:0] 	rate_and_mod		; // code rate and modulation mode
	reg  	[11:0]	byte_length 		; // byte length of one pkt, need to be reversed, LSB first, MSB least
	reg  			byte_reverse_valid	;
	wire  			even_parity_bit 	; // even parity bit of the signal domain
	reg  	[23:0]	signal_frame_withou_parity;
	wire  	[23:0] 	s  					;
	reg   			signal_frame_withou_parity_valid;
	reg  	[23:0] 	signal_frame_with_parity;
	reg  	[5:0]	cnt_data_bit 		;

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			rate_and_mod <= 'd0;
		end
		else if(preamble_ready == 1'b1) begin
			case(tx_Rate)
				6'd54: rate_and_mod <= 4'b0011; 	// 64QAM, 3/4 code rate
				6'd48: rate_and_mod <= 4'b0001; 	// 64QAM, 2/3 code rate
				6'd36: rate_and_mod <= 4'b1011; 	// 16QAM, 3/4 code rate
				6'd24: rate_and_mod <= 4'b1001; 	// 16QAM, 2/3 code rate
				6'd18: rate_and_mod <= 4'b0111;	// QPSK, 3/4 code rate
				6'd12: rate_and_mod <= 4'b0101; 	// QPSK, 2/3 code rate
				6'd9 : rate_and_mod <= 4'b1111; 	// BPSK, 3/4 code rate
				6'd6 : rate_and_mod <= 4'b1101; 	// BPSK, 1/2
				default : rate_and_mod <= 4'b0011;
			endcase
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			byte_length <= 'd0;
		end
		else if (preamble_ready == 1'b1) begin
			byte_length <= {packetlength[0], packetlength[1], packetlength[2], packetlength[3], packetlength[4], packetlength[5],
							packetlength[6], packetlength[7], packetlength[8], packetlength[9], packetlength[10], packetlength[11]};
		end
	end

	//---------------byte_reverse_valid-------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			byte_reverse_valid <= 1'b0;
		end
		else if (preamble_ready) begin
			byte_reverse_valid <= 1'b1;
		end
		else begin
			byte_reverse_valid <= 1'b0;
		end
	end

	//----------------signal_frame_withou_parity------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			signal_frame_withou_parity <= 'd0;
			signal_frame_withou_parity_valid <= 'd0;
		end
		else if (byte_reverse_valid == 1'b1) begin
			signal_frame_withou_parity_valid <= 1'b1;
			signal_frame_withou_parity <= {rate_and_mod, 1'b0, byte_length, 1'b0, 6'b000000};
		end
		else begin
			signal_frame_withou_parity_valid <= 1'b0;
		end
	end

	//----------------signal_frame_with_parity------------------
	assign s = signal_frame_withou_parity;
	assign even_parity_bit = ^s[23:7];

	always @(posedge clk_Modulation)begin
		if(reset == 1'b1) begin
			signal_frame_with_parity <= 'd0;
		end
		else if (signal_frame_withou_parity_valid) begin
			signal_frame_with_parity[6] <= even_parity_bit;
			signal_frame_with_parity[23:7] <=signal_frame_withou_parity[23:7];
			signal_frame_with_parity[5:0] <= signal_frame_withou_parity[5:0];
		end
		else if (tx_gen_pkt_sig_valid == 1'b1) begin
			signal_frame_with_parity <= {signal_frame_with_parity[22:0], 1'b0};
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_gen_pkt_sig_valid <= 1'b0;
		end
		else if (cnt_data_bit == 'd23 && tx_gen_pkt_sig_valid == 1'b1) begin
			tx_gen_pkt_sig_valid <= 1'b0;
		end
		else if (signal_frame_withou_parity_valid) begin
			tx_gen_pkt_sig_valid <= 1'b1;
		end
	end

	//----------------cnt_data_bit------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_data_bit <= 'd0;
		end
		else if (cnt_data_bit == 'd23 && tx_gen_pkt_sig_valid == 1'b1) begin
			cnt_data_bit <= 'd0;
		end
		else if(tx_gen_pkt_sig_valid == 1'b1)begin
			cnt_data_bit <= cnt_data_bit + 1'b1;
		end
	end

	assign tx_gen_pkt_sig_out = signal_frame_with_parity[23];



endmodule
