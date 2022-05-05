// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_modulate
// Create 	 : 2022-04-19
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : tx constellation mapping, add pilot to the channel,
// 			   the 802.11 ofdm modulation use bandwidth 20M divided into 64 channel,
//			   the ofdm use 48 channel + 1 DC channel + 4 pilot channel, other channel
//  		   is used as GI. This module generate the QAM64 constellation map, and the 
// 			   the pilot to the ofdm symble.
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tx_modulate(
	input 	wire		clk_Modulation				,
	input 	wire		reset						,
	input 	wire		tx_modulate_in_valid		,
	input 	wire		tx_modulate_in_bit			,
	input 	wire		tx_freq_to_timed_cycle_flag	,
	output 	reg [15:0]	n_ofdm_syms					,
	output 	reg 		tx_modulate_out_valid		,
	output 	reg [31:0]	tx_modulate_re_out			,
	output 	reg [31:0]	tx_modulate_im_out
    );

	//====================================================
	// paramter define
	//====================================================
	localparam IDLE  	= 3'b001;
	localparam MODULATE = 3'b010;
	localparam ARBIT 	= 3'b100;	

	//----------------QAM64 I/Q mapping------------------
	//Fixed-point quantization, 1 sign bit, 1 bit interger, 30bit decimal
	localparam QAM64_IQ_B000 = 3135193572; //3'b000 ==> -7, -7/sqrt(42) ==>3135193572
	localparam QAM64_IQ_B001 = 3466557494; //3'b001 ==> -5, -5/sqrt(42) ==>3466557494
	localparam QAM64_IQ_B011 = 3797921415; //3'b011 ==> -3, -3/sqrt(42) ==> 3,797,921,415
	localparam QAM64_IQ_B010 = 4129285336; //3'b010 ==> -1, -1/sqrt(42) ==>4,129,285,336
	localparam QAM64_IQ_B110 = 165681960 ; //3'b110 ==> 1, 1/sqrt(42) ==>165,681,960
	localparam QAM64_IQ_B111 = 497045881 ; //3'b111 ==> 3, 3/sqrt(42) ==>497045881
	localparam QAM64_IQ_B101 = 828409802 ; //3'b101 ==> 5, 5/sqrt(42) ==>828409802
	localparam QAM64_IQ_B100 = 1159773723; //3'b100 ==> 7, 7/sqrt(42) ==> 1159773723

	localparam QAM64_IQ_ONE = 1073741824;
	localparam QAM64_IQ_MINUS_ONE = 3221225472;
	
	//====================================================
	// internal signals and registers
	//====================================================
	reg   			tx_modulate_in_valid_dly		; 
	wire  			tx_modulate_in_valid_neg_pls	;
	reg  	[5:0] 	constellation_point 			; // serial bit to parallel constellation ponit
	reg  			constellation_point_vld			; // constellation point valid
	reg 	[3:0]	cnt_data_in 					; // counter for the data shift register
	reg		[15:0]	cnt_constellation_point 		; // counter for constellation point
	reg  	[15:0]	num_of_constellation_point 		; // total number of constellation point
	reg   			num_of_constellation_point_vld 	;

	wire  	[23:0] 	divider_result 					;
	wire   			divider_result_vld 				;

	reg   	[2:0]	state  							; // state register
	reg  	[7:0]	cnt_mapping 					;
	reg   			rd_fifo_en  					;
	wire    [5:0] 	rd_fifo_dout 					;
	wire   			full,empty  					;
	reg  	[7:0]	rom_addr 						;
	wire   			rom_dout 						;

	//----------------tx_modulate_in_valid_dly------------------
	always @(posedge clk_Modulation) begin
		tx_modulate_in_valid_dly <= tx_modulate_in_valid;
	end
	assign tx_modulate_in_valid_neg_pls = tx_modulate_in_valid_dly & (~tx_modulate_in_valid);

	//----------------constellation_ponit------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			constellation_point <= 'd0;
		end
		else if(tx_modulate_in_valid_neg_pls)begin
			constellation_point <= 'd0;
		end
		else if(tx_modulate_in_valid)begin
			constellation_point <= {constellation_point[4:0], tx_modulate_in_bit};
		end
	end

	//----------------cnt_data_in------------------
	always @(posedge clk_Modulation) begin
		if (reset == 11'b1) begin
			cnt_data_in <= 'd0;
		end
		else if(tx_modulate_in_valid == 1'b1 && cnt_data_in == 'd5)begin
			cnt_data_in <= 'd0;
		end
		else if(tx_modulate_in_valid == 1'b1)begin
			cnt_data_in <= cnt_data_in + 1'b1;
		end
	end

	//---------------constellation_point_vld-------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			constellation_point_vld <= 1'b0;
		end
		else if(tx_modulate_in_valid == 1'b1 && cnt_data_in == 'd5)begin
			constellation_point_vld <= 1'b1;
		end
		else begin
			constellation_point_vld <= 1'b0;
		end
	end

	//----------------cnt_constellation_point------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			cnt_constellation_point <= 'd0;
		end
		else if(tx_modulate_in_valid_neg_pls)begin
			cnt_constellation_point <= 'd0;
		end
		else if(tx_modulate_in_valid == 1'b1 && cnt_data_in == 'd5)begin
			cnt_constellation_point <= cnt_constellation_point + 1'b1;
		end
	end

	//----------------num_of_constellation_point------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			num_of_constellation_point <= 'd0;
			num_of_constellation_point_vld <= 1'b0;
		end
		else if (tx_modulate_in_valid_neg_pls) begin
			num_of_constellation_point <= cnt_constellation_point;
			num_of_constellation_point_vld <= 1'b1;
		end
		else begin
			num_of_constellation_point_vld <= 1'b0;
		end
	end

	div_gen_0 u_ofdm_symbol_cal (
		.aclk(clk_Modulation),                                      // input wire aclk
		.s_axis_divisor_tvalid(num_of_constellation_point_vld),    // input wire s_axis_divisor_tvalid
		.s_axis_divisor_tdata(8'd48),      // input wire [7 : 0] s_axis_divisor_tdata
		.s_axis_dividend_tvalid(num_of_constellation_point_vld),  // input wire s_axis_dividend_tvalid
		.s_axis_dividend_tdata(num_of_constellation_point),    // input wire [15 : 0] s_axis_dividend_tdata
		.m_axis_dout_tvalid(divider_result_vld),          // output wire m_axis_dout_tvalid
		.m_axis_dout_tdata(divider_result)            // output wire [23 : 0] m_axis_dout_tdata
	);

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			n_ofdm_syms <= 'd0;
		end
		else if(divider_result_vld)begin
			n_ofdm_syms <=divider_result[23:8];
		end
	end

	fifo_generator_tx_modulate u_fifo_generator_tx_modulate (
		.clk(clk_Modulation),      // input wire clk
		.srst(reset),    // input wire srst
		.din(constellation_point),      // input wire [5 : 0] din
		.wr_en(constellation_point_vld),  // input wire wr_en
		.rd_en(rd_fifo_en),  // input wire rd_en
		.dout(rd_fifo_dout),    // output wire [5 : 0] dout
		.full(full),    // output wire full
		.empty(empty)  // output wire empty
	);

	tx_pilot_rom u_tx_pilot_rom (
		.clka(clk_Modulation),    // input wire clka
		.addra(rom_addr),  // input wire [6 : 0] addra
		.douta(rom_dout)  // output wire [0 : 0] douta
	);

	//----------------state------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			state <= IDLE;
		end
		else begin
			case(state)
				IDLE : begin
					if(tx_modulate_in_valid_neg_pls)begin
						state <= MODULATE;
					end
				end

				MODULATE : begin
					if (cnt_mapping == 'd51) begin
						state <= ARBIT;
					end
				end

				ARBIT : begin
					if(empty == 1'b1)begin
						state <= IDLE;
					end
					else if(tx_freq_to_timed_cycle_flag == 1'b1 && empty==1'b0)begin
						state <= MODULATE;
					end
				end

				default : state <= IDLE;
			endcase
		end
	end

	//----------------cnt_mapping------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_mapping <= 'd0;
		end
		else if (state == MODULATE && cnt_mapping == 'd51) begin
			cnt_mapping <= 'd0;
		end
		else if (state == MODULATE) begin
			cnt_mapping <= cnt_mapping + 1'b1;
		end
		else begin
			cnt_mapping <= 'd0;
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			rom_addr <= 'd0;
		end
		else if (tx_modulate_in_valid_neg_pls) begin
			rom_addr <= 1;
		end
		else if (state == MODULATE && cnt_mapping == 'd51 && rom_addr == 126) begin
			rom_addr <= 'd0;
		end
		else if (state == MODULATE && cnt_mapping == 'd51 ) begin
			rom_addr <= rom_addr + 1'b1;
		end
	end

	//----------------rd_fifo_en------------------
	always @(*) begin
		if (state == MODULATE) begin
			if (cnt_mapping == 'd5 || cnt_mapping == 'd19 || cnt_mapping == 'd32 || cnt_mapping == 'd46) begin
				rd_fifo_en = 1'b0;
			end
			else begin
				rd_fifo_en = 1'b1;
			end
		end
		else begin
			rd_fifo_en = 1'b0;
		end
	end

	//------------------tx_modulate_re_out----------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_modulate_re_out <= 'd0;
		end
		else if(state == MODULATE)begin
			// insert pilot according to the pilot index,when rom dout is 1, the inserted pilot is 1 1 1 -1
			// when rom dout is 0 the inserted pilot is -1 -1 -1 1
			if(cnt_mapping == 'd5 || cnt_mapping == 'd19 || cnt_mapping =='d32)begin
				if (rom_dout == 1'b1) begin
					tx_modulate_re_out <= QAM64_IQ_ONE;
				end
				else begin
					tx_modulate_re_out <= QAM64_IQ_MINUS_ONE;
				end
			end
			else if (cnt_mapping == 'd46) begin
				if (rom_dout == 1'b1) begin
					tx_modulate_re_out <= QAM64_IQ_MINUS_ONE;
				end
				else begin
					tx_modulate_re_out <= QAM64_IQ_ONE;
				end
			end
			else begin
				case(rd_fifo_dout[5:3])
					3'b000: tx_modulate_re_out <= QAM64_IQ_B000;
					3'b001: tx_modulate_re_out <= QAM64_IQ_B001;
					3'b010: tx_modulate_re_out <= QAM64_IQ_B010;
					3'b011: tx_modulate_re_out <= QAM64_IQ_B011;
					3'b100: tx_modulate_re_out <= QAM64_IQ_B100;
					3'b101: tx_modulate_re_out <= QAM64_IQ_B101;
					3'b110: tx_modulate_re_out <= QAM64_IQ_B110;
					3'b111: tx_modulate_re_out <= QAM64_IQ_B111;
					default : tx_modulate_re_out <= 'd0;
				endcase
			end
		end
		else begin
			 tx_modulate_re_out <= 'd0;
		end
	end

		//------------------tx_modulate_im_out----------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_modulate_im_out <= 'd0;
		end
		else if(state == MODULATE)begin
			// insert pilot according to the pilot index,when rom dout is 1, the inserted pilot is 1 1 1 -1
			// when rom dout is 0 the inserted pilot is -1 -1 -1 1
			if(cnt_mapping == 'd5 || cnt_mapping == 'd19 || cnt_mapping =='d32 || cnt_mapping == 'd46)begin
				 tx_modulate_im_out <= 'd0;
			end
			else begin
				case(rd_fifo_dout[2:0])
					3'b000: tx_modulate_im_out <= QAM64_IQ_B000;
					3'b001: tx_modulate_im_out <= QAM64_IQ_B001;
					3'b010: tx_modulate_im_out <= QAM64_IQ_B010;
					3'b011: tx_modulate_im_out <= QAM64_IQ_B011;
					3'b100: tx_modulate_im_out <= QAM64_IQ_B100;
					3'b101: tx_modulate_im_out <= QAM64_IQ_B101;
					3'b110: tx_modulate_im_out <= QAM64_IQ_B110;
					3'b111: tx_modulate_im_out <= QAM64_IQ_B111;
					default : tx_modulate_im_out <= 'd0;
				endcase
			end
		end
		else begin
			 tx_modulate_im_out <= 'd0;
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_modulate_out_valid <= 1'b0;
		end
		else if (state == MODULATE) begin
			tx_modulate_out_valid <= 1'b1;
		end
		else begin
			tx_modulate_out_valid <= 1'b0;
		end
	end








endmodule
