// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_out_arrange
// Create 	 : 2022-04-26
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : 
// 			   
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tx_out_arrange(
	input 	wire  			clk_Modulation						,
	input 	wire  			reset								,
	input 	wire  	[1:0]	tx_Upsample							,
	input 	wire  			user_tx_data_start					,
	input 	wire  			tx_add_cyclic_prefix_valid			,
	input 	wire  			tx_add_cyclic_prefix_end			,
	input 	wire  	[15:0]	tx_add_cyclic_prefix_re				,
	input 	wire  	[15:0]	tx_add_cyclic_prefix_im				,
	input 	wire  			tx_gen_sig_add_cyclic_prefix_valid	,
	input 	wire  	[15:0]	tx_gen_sig_add_cyclic_prefix_re		,
	input 	wire  	[15:0]	tx_gen_sig_add_cyclic_prefix_im		,
	output 	reg 			preamble_ready						,
	output 	wire 			tx_802p11_out_valid					,
	output 	wire 	[15:0]	tx_802p11_re_out					,
	output 	wire 	[15:0]	tx_802p11_im_out
    );

	//====================================================
	// parameter define
	//====================================================
	localparam PREAMBLE_LEN = 640;
	localparam SIGNAL_LEN 	= 160;

	localparam IDLE = 5'b00001;
	localparam PREAMBLE = 5'b00010;
	localparam SIGNAL = 5'b00100;
	localparam DATA = 5'b01000;
	localparam READ_FIFO = 5'b10000;

	//====================================================
	// internal signals and registers
	//====================================================
	reg  	[4:0]	state 			;
	reg  	[1:0]	tx_upsample_reg ;
 	reg   			rd_rom_en 		;
	reg		[9:0]	rom_addr 		;
	wire 	[15:0]	rom_dout_re 	;
	wire 	[15:0]	rom_dout_im 	;
	reg  			rom_dout_valid	;
	wire  			rd_rom_en_neg_pls;

	reg  	[17:0] 	cnt_data_in 	;
	
	reg  			wr_fifo_en 		;
	reg  	[31:0]	wr_fifo_din 	;
	wire   			rd_fifo_en 		;
	wire  	[31:0] 	rd_fifo_dout 	;

	wire   			fifo_empty;
	wire  			fifo_full;


	//----------------state------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			state <= IDLE;
		end
		else begin
			case(state)
				IDLE : begin
					if(user_tx_data_start)begin
						state <= PREAMBLE;
					end
				end
				
				PREAMBLE : begin
					if(cnt_data_in == PREAMBLE_LEN - 1)begin
						state <= SIGNAL;
					end
				end

				SIGNAL : begin
					if (cnt_data_in == (PREAMBLE_LEN + SIGNAL_LEN - 1)) begin
						state <= DATA;
					end
				end

				DATA : begin
					if(tx_add_cyclic_prefix_end)begin
						state <= READ_FIFO;
					end
				end

				READ_FIFO : begin
					if(fifo_empty == 1'b1)begin
						state <= IDLE;
					end
				end

				default : begin
					state <= IDLE;
				end
			endcase
		end
	end

	//----------------tx_upsample_reg------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_upsample_reg <= 'd0;
		end
		else if (user_tx_data_start == 1'b1) begin
			tx_upsample_reg <= tx_Upsample;
		end
	end

	//----------------rd_rom_en------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			rd_rom_en <= 1'b0;
		end
		else if (rd_rom_en == 1'b1 && rom_addr == PREAMBLE_LEN - 1) begin
			rd_rom_en <= 1'b0;
		end
		else if (user_tx_data_start == 1'b1) begin
			rd_rom_en <= 1'b1;
		end
	end

	//----------------rom_dout_valid------------------
	always @(posedge clk_Modulation) begin
		rom_dout_valid <= rd_rom_en;
	end

	//----------------rom_addr------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			rom_addr <= 'd0;
		end
		else if (rd_rom_en == 1'b1 && rom_addr == PREAMBLE_LEN - 1) begin
			rom_addr <= 'd0;
		end
		else if (rd_rom_en == 1'b1) begin
			rom_addr <= rom_addr + 1'b1;
		end
	end

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			preamble_ready <= 1'b0;
		end
		else if (cnt_data_in == PREAMBLE_LEN - 1) begin
			preamble_ready <= 1'b1;
		end
		else begin
			preamble_ready <= 1'b0;
		end
	end


	blk_mem_preamble_im u_blk_mem_preamble_im (
		.clka(clk_Modulation),    // input wire clka
		.addra(rom_addr),  // input wire [9 : 0] addra
		.douta(rom_dout_im)  // output wire [15 : 0] douta
	);
	blk_mem_preamble_re u_blk_mem_preamble_re (
		.clka(clk_Modulation),    // input wire clka
		.addra(rom_addr),  // input wire [9 : 0] addra
		.douta(rom_dout_re)  // output wire [15 : 0] douta
	);
	
	//----------------cnt_data_in------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_data_in <= 'd0;
		end
		else if(tx_add_cyclic_prefix_end)begin
			cnt_data_in <= 'd0;
		end
		else if (state == PREAMBLE && rom_dout_valid == 1'b1) begin
			cnt_data_in <= cnt_data_in + 1'b1;
		end
		else if (state == SIGNAL && tx_gen_sig_add_cyclic_prefix_valid == 1'b1) begin
			cnt_data_in <= cnt_data_in + 1'b1;
		end
		else if (state == DATA && tx_add_cyclic_prefix_valid == 1'b1) begin
			cnt_data_in <= cnt_data_in + 1'b1;
		end
	end

	always @(*) begin
		case(state)
			PREAMBLE: wr_fifo_din = {rom_dout_im, rom_dout_re};
			SIGNAL: wr_fifo_din = {tx_gen_sig_add_cyclic_prefix_im, tx_gen_sig_add_cyclic_prefix_re};
			DATA : wr_fifo_din = {tx_add_cyclic_prefix_im, tx_add_cyclic_prefix_re};
			default: wr_fifo_din = 'd0;
		endcase
	end

	always @(*) begin
		if (tx_upsample_reg == 'd1) begin
			if (cnt_data_in[0] == 1'b1) begin
				wr_fifo_en = 1'b1;
			end
			else begin
				wr_fifo_en = 1'b0;
			end
		end
		else if(tx_upsample_reg == 'd2)begin
			wr_fifo_en = rom_dout_valid | tx_gen_sig_add_cyclic_prefix_valid | tx_add_cyclic_prefix_valid;
		end
		else begin
			wr_fifo_en = 1'b0;
		end
	end

	fifo_generator_tx_out_arrange u_fifo_generator_tx_out_arrange (
		.clk(clk_Modulation),      // input wire clk
		.srst(reset),    // input wire srst
		.din(wr_fifo_din),      // input wire [31 : 0] din
		.wr_en(wr_fifo_en),  // input wire wr_en
		.rd_en(rd_fifo_en),  // input wire rd_en
		.dout(rd_fifo_dout),    // output wire [31 : 0] dout
		.full(fifo_full),    // output wire full
		.empty(fifo_empty)  // output wire empty
	);

	assign rd_fifo_en = (state == READ_FIFO) ? (~fifo_empty) : 1'b0;
	assign tx_802p11_out_valid = rd_fifo_en;
	assign tx_802p11_im_out = rd_fifo_dout[31:16];
	assign tx_802p11_re_out = rd_fifo_dout[15:0];

endmodule
