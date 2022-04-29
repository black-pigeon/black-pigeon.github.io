// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : tx_generate_data
// Create 	 : 2022-04-13
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : generate plcp data
// 			   
// -----------------------------------------------------------------------------

module tx_generate_data (
    input   wire        clk_User        ,
    input   wire        reset           ,
    input   wire [5:0]  tx_Rate         , // data rate default 54Mb/s(20MHz width)
    input   wire        send_data_valid ,
    input   wire [7:0]  send_data       ,
    input   wire [15:0] packetlength    ,

    input   wire        clk_Modulation  ,
    output  reg         data_bit_valid  ,
    output  reg         data_bit 
);
reg     [1:0]   send_data_valid_dly ;
reg     [15:0]  send_data_dly       ;
wire            send_data_valid_pos_pls;
reg     [7:0]   bits_per_symbol     ;
reg     [23:0]  num_of_data_bits    ;

wire    [31:0]  divider_out         ;
wire            divider_out_valid   ;

reg     [23:0]  num_of_symbol       ;
reg             num_of_symbol_valid ;
wire    [31:0]  num_of_total_bits   ;
reg             num_of_toyal_bit_valid;
reg     [31:0]  num_of_pad_bits     ;

wire            wr_fifo_en          ;
wire    [7:0]   wr_fifo_din         ;
wire            rd_fifo_en          ;
wire            rd_fifo_dout        ;
wire            full                ;
wire            empty               ;

reg             rd_fifo_en_dly      ;
wire            rd_fifo_en_neg_pls  ;
reg             pad_flag            ;
reg     [31:0]  cnt_pad             ;

//----------------send_data_valid_dly/send_data_dly------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        send_data_dly <= 'd0;
        send_data_valid_dly <= 'd0;
    end
    else begin
        send_data_dly <= {send_data_dly[7:0], send_data};
        send_data_valid_dly <= {send_data_valid_dly[0], send_data_valid};
    end
end

// insert 2bytes 0x00 in front of the valid data
assign wr_fifo_en = send_data_valid_dly[1] | send_data_valid;
assign wr_fifo_din = send_data_dly[15:8];

// posedge of send_data_vlaid, used as the divider input valid signal
assign send_data_valid_pos_pls = (~send_data_valid_dly[0]) & send_data_valid;


//----------------bits_per_symbol------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        bits_per_symbol <= 'd0;
    end
    else begin
        bits_per_symbol <= tx_Rate << 2;
    end
end

//----------------num_of_data_bits------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        num_of_data_bits <= 'd0;
    end
    else begin
        // data region data bits, 16bit service ID + data bits + 6bit tail bits
        num_of_data_bits <= 16 + (packetlength<<3) + 6;
    end
end

//----------------num_of_symbol------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        num_of_symbol <= 'd0;
    end
    else if(divider_out_valid)begin
        num_of_symbol <= divider_out[31:8] + (|divider_out[7:0]);
    end
end

always @(posedge clk_User) begin
    if (reset == 1'b1) begin
        num_of_symbol_valid <= 1'b0;
        num_of_toyal_bit_valid <= 1'b0;
    end
    else begin
        num_of_symbol_valid <= divider_out_valid;
        num_of_toyal_bit_valid <= num_of_symbol_valid;
    end
end

//----------------num_of_pad_bits------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        num_of_pad_bits <= 'd0;
    end
    else if(num_of_toyal_bit_valid == 1'b1)begin
        num_of_pad_bits <= num_of_total_bits - num_of_data_bits;
    end
end

assign rd_fifo_en = ~empty;

fifo_generator_8to1 u_fifo_generator_8to1 (
  .rst(reset),        // input wire rst
  .wr_clk(clk_User),  // input wire wr_clk
  .rd_clk(clk_Modulation),  // input wire rd_clk
  .din(wr_fifo_din),        // input wire [7 : 0] din
  .wr_en(wr_fifo_en),    // input wire wr_en
  .rd_en(rd_fifo_en),    // input wire rd_en
  .dout(rd_fifo_dout),      // output wire [0 : 0] dout
  .full(full),      // output wire full
  .empty(empty)    // output wire empty
);


ofdm_symbol_divider u_ofdm_symbol_divider (
  .aclk(clk_User),                                  // input wire aclk
  .s_axis_divisor_tvalid(send_data_valid_pos_pls),  // input wire s_axis_divisor_tvalid
  .s_axis_divisor_tdata(bits_per_symbol),           // input wire [7 : 0] s_axis_divisor_tdata
  .s_axis_dividend_tvalid(send_data_valid_pos_pls), // input wire s_axis_dividend_tvalid
  .s_axis_dividend_tdata(num_of_data_bits),         // input wire [23 : 0] s_axis_dividend_tdata
  .m_axis_dout_tvalid(divider_out_valid),           // output wire m_axis_dout_tvalid
  .m_axis_dout_tdata(divider_out)                   // output wire [31 : 0] m_axis_dout_tdata
);

ofdm_bits_multiplier u_ofdm_bits_multiplier (
  .CLK(clk_User),  // input wire CLK
  .A(num_of_symbol),      // input wire [23 : 0] A
  .B(bits_per_symbol),      // input wire [7 : 0] B
  .P(num_of_total_bits)      // output wire [31 : 0] P
);


//----------------rd_fifo_en_dly------------------
always @(posedge clk_Modulation) begin
    rd_fifo_en_dly <= rd_fifo_en;
end

assign rd_fifo_en_neg_pls = rd_fifo_en_dly & (~rd_fifo_en);

//----------------pad_flag------------------
always@(posedge clk_Modulation)begin
    if (reset == 1'b1) begin
        pad_flag <= 1'b0;
    end
    else if((cnt_pad == (num_of_pad_bits + 6 - 1)) && (pad_flag == 1'b1))begin
        pad_flag <= 1'b0;
    end
    else if (rd_fifo_en_neg_pls == 1'b1) begin
        pad_flag <= 1'b1;
    end
end

//----------------cnt_pad------------------
always @(posedge clk_Modulation) begin
    if (reset == 1'b1) begin
        cnt_pad <= 'd0;
    end
    else if((cnt_pad == (num_of_pad_bits + 6 - 1)) && (pad_flag == 1'b1))begin
        cnt_pad <= 'd0;
    end
    else if (rd_fifo_en_neg_pls | pad_flag) begin
        cnt_pad <= cnt_pad + 1'b1;
    end
end

//----------------data_bit------------------
always @(posedge clk_Modulation) begin
    if (reset == 1'b1) begin
        data_bit <= 1'b0;
    end
    else if(rd_fifo_en)begin
        data_bit <= rd_fifo_dout;
    end
    else if(rd_fifo_en_neg_pls | pad_flag)begin
        data_bit <= 1'b0;
    end
end

always@(posedge clk_Modulation)begin
    if (reset == 1'b1) begin
        data_bit_valid <= 1'b0;
    end
    else if(rd_fifo_en | rd_fifo_en_neg_pls | pad_flag) begin
        data_bit_valid <= 1'b1;
    end
    else begin
        data_bit_valid <= 1'b0;
    end
end

    
endmodule