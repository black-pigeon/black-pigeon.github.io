// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_gen_sig_modulate
// Create 	 : 2022-04-24
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : ofdm signal domain QAM64 madulation
// 			   
// -----------------------------------------------------------------------------

`timescale 1ns / 1ps
module tx_gen_sig_modulate(
	input 	wire   		clk_Modulation					,
	input 	wire   		reset							,
	input 	wire   		tx_gen_sig_modulate_in_valid	,
	input 	wire   		tx_gen_sig_modulate_in_bit		,
	output 	reg 		tx_gen_sig_modulate_valid		,
	output 	reg [31:0]	tx_gen_sig_modulate_re			,
	output 	reg [31:0]	tx_gen_sig_modulate_im	
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

	localparam BPSK_IQ_ONE = 1073741824;
	localparam BPSK_IQ_MINUS_ONE = 3221225472;

	localparam QAM64_IQ_ONE = 1073741824;
	localparam QAM64_IQ_MINUS_ONE = 3221225472;
	
	//====================================================
	// internal signals and registers
	//====================================================
	reg   			tx_modulate_in_valid_dly		; 
	wire  			tx_modulate_in_valid_neg_pls	;


	reg   	[2:0]	state  							; // state register
	reg  	[7:0]	cnt_mapping 					;
	reg   			rd_fifo_en  					;
	wire         	rd_fifo_dout 					;
	wire   			full,empty  					;

	//----------------tx_modulate_in_valid_dly------------------
	always @(posedge clk_Modulation) begin
		tx_modulate_in_valid_dly <= tx_gen_sig_modulate_in_valid;
	end
	assign tx_modulate_in_valid_neg_pls = tx_modulate_in_valid_dly & (~tx_gen_sig_modulate_in_valid);

	
	fifo_tx_gen_sig_modulate_48_52 u_fifo_tx_gen_sig_modulate_48_52 (
		.clk(clk_Modulation),      // input wire clk
		.srst(reset),    // input wire srst
		.din(tx_gen_sig_modulate_in_bit),      // input wire [0 : 0] din
		.wr_en(tx_gen_sig_modulate_in_valid),  // input wire wr_en
		.rd_en(rd_fifo_en),  // input wire rd_en
		.dout(rd_fifo_dout),    // output wire [0 : 0] dout
		.full(full),    // output wire full
		.empty(empty)  // output wire empty
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

	//------------------tx_gen_sig_modulate_re----------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_gen_sig_modulate_re <= 'd0;
		end
		else if(state == MODULATE)begin
			// insert pilot according to the pilot index,when rom dout is 1, the inserted pilot is 1 1 1 -1
			// when rom dout is 0 the inserted pilot is -1 -1 -1 1
			if(cnt_mapping == 'd5 || cnt_mapping == 'd19 || cnt_mapping =='d32)begin
				tx_gen_sig_modulate_re <= BPSK_IQ_ONE;
			end
			else if (cnt_mapping == 'd46) begin
				tx_gen_sig_modulate_re <= BPSK_IQ_MINUS_ONE;
			end
			else begin
				if(rd_fifo_dout == 1'b1)begin
					tx_gen_sig_modulate_re <= BPSK_IQ_ONE;
				end
				else begin
					tx_gen_sig_modulate_re <= BPSK_IQ_MINUS_ONE;
				end
			end
		end
		else begin
			 tx_gen_sig_modulate_re <= 'd0;
		end
	end

	//------------------tx_gen_sig_modulate_im----------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_gen_sig_modulate_im <= 'd0;
		end
		else if(state == MODULATE)begin
			// insert pilot according to the pilot index,when rom dout is 1, the inserted pilot is 1 1 1 -1
			// when rom dout is 0 the inserted pilot is -1 -1 -1 1
			if(cnt_mapping == 'd5 || cnt_mapping == 'd19 || cnt_mapping =='d32 || cnt_mapping == 'd46)begin
				 tx_gen_sig_modulate_im <= 'd0;
			end
			else begin
				tx_gen_sig_modulate_im <= 'd0;
			end
		end
		else begin
			 tx_gen_sig_modulate_im <= 'd0;
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_gen_sig_modulate_valid <= 1'b0;
		end
		else if (state == MODULATE) begin
			tx_gen_sig_modulate_valid <= 1'b1;
		end
		else begin
			tx_gen_sig_modulate_valid <= 1'b0;
		end
	end


endmodule
