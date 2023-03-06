// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : scramble_lc
// Create 	 : 2022-04-15
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : scramble the input data
// 			   
// -----------------------------------------------------------------------------

module scramble_lc (
	input  	wire  			clk_Modulation		,
	input 	wire  			reset 				,
	input 	wire 	[15:0]	packetlength 		,
	input 	wire  			data_bit_valid 		,
	input 	wire  			data_bit 			,
	output 	reg  			scramble_bit_valid	,
	output 	reg  			scramble_bit 
	);

	//====================================================
	// parameter define
	//====================================================
	localparam SCRAMBLE_REG_INIT = 7'b0001111;
	localparam TAIL_BIT_LENGTH = 6;

	//====================================================
	// internal signals and registers
	//====================================================
	reg 	[6:0]		h1; // scramble shift register
	reg  				h2;	// output of scramble shift register
	reg   				h2_valid		; // valid of scramble shift register output
	reg  				data_bit_dly	;
	reg  				scramble_data 	;
	reg  	[19:0]		tail_bit_start	; // start index of tail bits
	reg  				tail_bit_flag	; // tail bit flag
	reg  	[19:0]		cnt_bit 		;
	reg  				scramble_bit_valid_dly 	;
	wire  				scramble_bit_valid_neg_pls;


	//----------------h1------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			h1 <= SCRAMBLE_REG_INIT;
		end
		else if (scramble_bit_valid_neg_pls) begin
			h1 <= SCRAMBLE_REG_INIT;
		end
		else if(data_bit_valid) begin
			h1 <= {h1[5:0], h1[6]^h1[3]};
		end
	end

	//----------------h2------------------
	always@(posedge clk_Modulation)begin
		if (reset == 1'b1) begin
			h2 <= 1'b0;
		end
		else if(scramble_bit_valid_neg_pls)begin
			h2 <= 1'b0;
		end
		else if(data_bit_valid)begin
			h2 <= h1[6]^h1[3];
		end
	end

	//----------------data_bit_dly------------------
	always@(posedge clk_Modulation)begin
		data_bit_dly <= data_bit;
	end

	//----------------h2_valid------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			h2_valid <= 1'b0;
		end
		else begin
			h2_valid <= data_bit_valid;
		end
	end

	//----------------scramble_bit_valid------------------
	always@(posedge clk_Modulation)begin
		if (reset == 1'b1) begin
			scramble_bit_valid <= 1'b0;
		end
		else begin
			scramble_bit_valid <= h2_valid;
		end
	end

	//---------------scramble_data-------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			scramble_data <= 1'b0;
		end
		else if(h2_valid == 1'b1)begin
			scramble_data <= h2 ^ data_bit_dly;
		end
	end

	//----------------tail_bit_start------------------
	always@(posedge clk_Modulation)begin
		if (reset == 1'b1) begin
			tail_bit_start <= 'd0;
		end
		else begin
			tail_bit_start <= (packetlength<<3) + 16;
		end
	end

	//----------------cnt_bit------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			cnt_bit <= 'd0;
		end
		else if(scramble_bit_valid == 1'b1)begin
			cnt_bit <= cnt_bit + 1'b1;
		end
		else begin
			cnt_bit <= 'd0;
		end
	end

	//----------------tail_bit_flag------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			tail_bit_flag <= 1'b0;
		end
		else if(cnt_bit == (tail_bit_start+TAIL_BIT_LENGTH -1))begin
			tail_bit_flag <= 1'b0;
		end
		else if(cnt_bit == (tail_bit_start - 1))begin
			tail_bit_flag <= 1'b1;
		end
	end

	//----------------scramble_bit_valid_dly------------------
	always@(posedge clk_Modulation)begin
		scramble_bit_valid_dly <= scramble_bit_valid;
	end
	assign scramble_bit_valid_neg_pls = scramble_bit_valid_dly & (~scramble_bit_valid);

	always @(*)begin
		if(scramble_bit_valid)begin
			if(tail_bit_flag)begin
				scramble_bit = 1'b0;
			end
			else begin
				scramble_bit = scramble_data;
			end
		end
		else begin
			scramble_bit = 1'b0;
		end
	end


	
	
	
endmodule