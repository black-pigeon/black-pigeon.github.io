// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_conv_encoder
// Create 	 : 2022-04-15
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : convolution encoder
// 			   
// -----------------------------------------------------------------------------
module tx_conv_encoder (
	input 	wire 			clk_Modulation	,
	input 	wire 			reset 			,
	input 	wire  			tx_conv_encoder_valid	,
	input 	wire  			tx_conv_encoder_bit 	,
	output 	reg  			tx_conv_valid 			,
	output 	wire  [1:0]		tx_conv_bit		
	);


	wire [6:0]	conv_coef1;
	wire [6:0]	conv_coef2;

	reg   		tx_conv_encoder_valid_dly;
	reg  		tx_conv_encoder_bit_dly;
	reg  [6:0]	conv_sft;
	reg   		tx_conv_valid_dly;
	wire  		tx_conv_valid_neg_pls;
	reg  		tx_conv_bit_a;
	reg  		tx_conv_bit_b;

	assign conv_coef1 = 7'b1101101;
	assign conv_coef2 = 7'b1001111;

	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_conv_encoder_valid_dly <= 1'b0;
			tx_conv_encoder_bit_dly <= 1'b0;
		end
		else begin
			tx_conv_encoder_valid_dly <= tx_conv_encoder_valid;		
			tx_conv_encoder_bit_dly	<= tx_conv_encoder_bit;	
		end
	end

	//----------------conv_sft------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			conv_sft <= 'd0;
		end
		else if(tx_conv_valid_neg_pls)begin
			conv_sft <= 'd0;
		end
		else if(tx_conv_encoder_valid)begin
			conv_sft <= {conv_sft[5:0], tx_conv_encoder_bit};
		end
	end

	//----------------tx_conv_valid_dly------------------
	always @(posedge clk_Modulation) begin
		tx_conv_valid_dly <= tx_conv_valid;
	end
	assign tx_conv_valid_neg_pls = tx_conv_valid_dly & (~tx_conv_valid);

	//-------------tx_conv_bit_a/b---------------------
	always @(posedge clk_Modulation) begin
		if (reset == 1'b1) begin
			tx_conv_bit_a <= 1'b0;
			tx_conv_bit_b <= 1'b0;
		end
		else if(tx_conv_valid_neg_pls)begin
			tx_conv_bit_a <= 1'b0;
			tx_conv_bit_b <= 1'b0;
		end
		else if(tx_conv_encoder_valid_dly)begin
			tx_conv_bit_a <= (conv_sft[6]&conv_coef1[6]) ^(conv_sft[5]&conv_coef1[5]) ^ (conv_sft[4]&conv_coef1[4])^ (conv_sft[3]&conv_coef1[3]) 
							^(conv_sft[2]&conv_coef1[2]) ^(conv_sft[1]&conv_coef1[1]) ^ (conv_sft[0]&conv_coef1[0]) ;
			tx_conv_bit_b <= (conv_sft[6]&conv_coef2[6]) ^(conv_sft[5]&conv_coef2[5]) ^ (conv_sft[4]&conv_coef2[4])^ (conv_sft[3]&conv_coef2[3]) 
							^(conv_sft[2]&conv_coef2[2]) ^(conv_sft[1]&conv_coef2[1]) ^ (conv_sft[0]&conv_coef2[0]) ;
			
		end
	end

	//----------------tx_conv_valid------------------
	always @(posedge clk_Modulation) begin
		if(reset == 1'b1)begin
			tx_conv_valid <= 1'b0;
		end
		else begin
			tx_conv_valid <= tx_conv_encoder_valid_dly;
		end
	end

	assign tx_conv_bit = {tx_conv_bit_a, tx_conv_bit_b};
endmodule