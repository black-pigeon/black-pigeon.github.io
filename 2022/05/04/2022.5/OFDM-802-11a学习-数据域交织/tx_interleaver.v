// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_interleaver
// Create 	 : 2022-04-18
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : OFDM transmitter interleave module
// 			   
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tx_interleaver (
	input	wire  			clk_Modulation	,
	input 	wire  			reset 			,
	input 	wire  	[1:0]	tx_Modulation		,//调制模式
	input 	wire 			tx_interleaver_in_valid	,
	input 	wire 			tx_interleaver_in_bit		,
	input 	wire 			tx_puncture_bit_cnt_valid	,
	input 	wire  	[15:0]	tx_puncture_bit_cnt	,
	output 	reg 			intlvr_patt_valid	,
	output 	reg 	[15:0]	intlvr_patt	,
	output 	wire 			interleaved_bit_valid,
	output 	wire 			interleaved_bit			

);

	//====================================================
	// internal signals and registers
	//====================================================
	reg  	[8:0]	multi_rate_rom_start_addr	; // the interleaver mapping rom start addr (depending on the code rate)
	reg  	[8:0]	multi_rate_rom_end_addr 	; // the interleaver mapping rom end addr (depending on the code rate)
	reg  	[8:0]	multi_rate_rom_length 		; // the length of interleaver mapping rom (depending on the code rate)

	reg  			tx_interleaver_in_valid_dly	;
	wire  			tx_interleaver_in_valid_neg_pls;

	reg  	[15:0]	cnt_data_in 				;
	reg  	[15:0]	data_len 					;

	reg  	[15:0]	cnt_fifo_rd 				;
	reg  			rd_rom_fifo_en 				;
	wire  			fifo_dout 					;
	wire  			full,empty 					;
	wire  	[8:0]	rom_dout 					;
	reg  	[8:0]	rom_addr					;

	reg   			wr_ram_en 					;
	reg  			wr_ram_en_dly 				;
	wire  			wr_ram_en_neg_pls 			;
	reg  	[15:0]	wr_ram_addr_base 			;
	wire  	[15:0]	wr_ram_addr 				;
	wire  	[15:0]	rd_ram_addr 				;
	reg  			rd_ram_en 					;
	reg  	[15:0]	cnt_ram_rd  				;
	wire  			ram_dout 					;
	reg  			ram_dout_valid				;

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			multi_rate_rom_start_addr <= 'd0; 
			multi_rate_rom_end_addr <= 'd0;
			multi_rate_rom_length <= 'd0;
		end
		else if(tx_Modulation == 'd3)begin
			multi_rate_rom_start_addr <= 'd0; 
			multi_rate_rom_end_addr <= 'd287;
			multi_rate_rom_length <= 'd288;
		end
	end

	//----------------cnt_data_in------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_data_in <= 'd0;
		end
		else if(tx_interleaver_in_valid)begin
			cnt_data_in <= cnt_data_in + 1'b1;
		end
		else begin
			cnt_data_in <= 'd0;
		end
	end

	always @(posedge clk_Modulation) begin
		tx_interleaver_in_valid_dly <= tx_interleaver_in_valid;
	end

	assign tx_interleaver_in_valid_neg_pls = tx_interleaver_in_valid_dly & (~tx_interleaver_in_valid);

	//----------------data_len------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			data_len <= 'd0;
		end
		else if(tx_interleaver_in_valid_neg_pls)begin
			data_len <= cnt_data_in;
		end
	end


	fifo_generator_tx_interleaver u_fifo_generator_tx_interleaver (
		.clk(clk_Modulation),      // input wire clk
		.srst(reset),    // input wire srst
		.din(tx_interleaver_in_bit),      // input wire [0 : 0] din
		.wr_en(tx_interleaver_in_valid),  // input wire wr_en
		.rd_en(rd_rom_fifo_en),  // input wire rd_en
		.dout(fifo_dout),    // output wire [0 : 0] dout
		.full(full),    // output wire full
		.empty(empty)  // output wire empty
	);

	blk_mem_gen_single_intlvr_patt u_blk_mem_gen_single_intlvr_patt (
		.clka(clk_Modulation),    // input wire clka
		.addra(rom_addr),  // input wire [8 : 0] addra
		.douta(rom_dout)  // output wire [8 : 0] douta
	);

	//----------------rd_rom_fifo_en------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			rd_rom_fifo_en <= 1'b0;
		end
		else if(rd_rom_fifo_en == 1'b1 && cnt_fifo_rd == data_len-1)begin
			rd_rom_fifo_en <= 1'b0;
		end
		else if(tx_interleaver_in_valid_neg_pls == 1'b1)begin
			rd_rom_fifo_en <= 1'b1;
		end
	end

	//----------------cnt_fifo_rd------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_fifo_rd <= 'd0;
		end
		else if (rd_rom_fifo_en == 1'b1 && cnt_fifo_rd == data_len-1) begin
			cnt_fifo_rd <= 'd0;
		end
		else if(rd_rom_fifo_en) begin
			cnt_fifo_rd <= cnt_fifo_rd + 1'b1;
		end
	end

	//----------------rom_addr------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			rom_addr <= 'd0;
		end
		else if(tx_interleaver_in_valid_neg_pls)begin
			rom_addr <= multi_rate_rom_start_addr;
		end
		else if ((rom_addr == multi_rate_rom_end_addr) && (rd_rom_fifo_en == 1'b1)) begin
			rom_addr <= multi_rate_rom_start_addr;
		end
		else if(rd_rom_fifo_en == 1'b1)begin
			rom_addr <= rom_addr + 1'b1;
		end
	end

	//----------------wr_ram_addr_base------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			wr_ram_addr_base <= 'd0;
		end
		else if(rd_rom_fifo_en == 1'b1)begin
			if(rom_addr == multi_rate_rom_length-1)begin
				wr_ram_addr_base <= wr_ram_addr_base + multi_rate_rom_length;
			end
		end
		else begin
			wr_ram_addr_base <= 'd0;
		end
	end

	assign wr_ram_addr = wr_ram_addr_base + rom_dout;

	always @(posedge clk_Modulation) begin
		wr_ram_en <= rd_rom_fifo_en;
		wr_ram_en_dly <= wr_ram_en;
	end
	assign wr_ram_en_neg_pls = (~wr_ram_en) & wr_ram_en_dly;

	blk_mem_gen_tx_interleaver u_blk_mem_gen_tx_interleaver (
		.clka(clk_Modulation),    // input wire clka
		.wea(wr_ram_en),      // input wire [0 : 0] wea
		.addra(wr_ram_addr),  // input wire [13 : 0] addra
		.dina(fifo_dout),    // input wire [0 : 0] dina
		.clkb(clk_Modulation),    // input wire clkb
		.enb(rd_ram_en),      // input wire enb
		.addrb(rd_ram_addr),  // input wire [13 : 0] addrb
		.doutb(ram_dout)  // output wire [0 : 0] doutb
	);
			
	//----------------rd_ram_en------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			rd_ram_en <= 1'b0;
		end
		else if(rd_ram_en == 1'b1 && cnt_ram_rd == data_len-1)begin
			rd_ram_en <= 1'b0;
		end
		else if(wr_ram_en_neg_pls)begin
			rd_ram_en <= 1'b1;
		end
	end

	//----------------cnt_ram_rd------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_ram_rd <= 'd0;
		end
		else if(rd_ram_en == 1'b1 && cnt_ram_rd == data_len-1)begin
			cnt_ram_rd <= 'd0;
		end
		else if(rd_ram_en == 1'b1)begin
			cnt_ram_rd <= cnt_ram_rd + 1'b1;
		end	
	end
	assign rd_ram_addr = cnt_ram_rd;

	//----------------rd_ram_valid------------------
	always @(posedge clk_Modulation) begin
		ram_dout_valid <= rd_ram_en;
	end

	assign interleaved_bit_valid = ram_dout_valid;
	assign interleaved_bit = ram_dout;
	
endmodule