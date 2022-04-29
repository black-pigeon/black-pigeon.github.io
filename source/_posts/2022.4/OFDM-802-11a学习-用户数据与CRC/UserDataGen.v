// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : UserDataGen
// Create 	 : 2022-04-12
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : Generate user data
// 			   
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module UserDataGen (
    input   wire            clk_User            , // user domain clock
    input   wire            reset               , // system reset

    output  reg            user_tx_data_start  , // start of user data
    output  reg            user_tx_data_end    , // end of yser data
    output  reg    [15:0]  packetlength        , // user data length including 4bytes crc
    output  reg            user_tx_data_valid  , // user data valid 
    output  wire   [7:0]   user_tx_data          // user data
);

reg [15:0]  packet_cnt_r    ;  
reg [15:0]  start_cnt_r     ;  
reg [15:0]  cycle_cnt_r     ;  

reg [15:0]  tvg_cnt         ; // counter for user data generation
reg [15:0]  pkt_cnt         ; // counter for pakcet length


//----------------register user packet info------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        packet_cnt_r <= 'd150; 
        start_cnt_r  <= 'd100;
        cycle_cnt_r  <= 'd19900;
    end
    else begin
        packet_cnt_r <= packet_cnt_r;    
        start_cnt_r  <= start_cnt_r;
        cycle_cnt_r  <= cycle_cnt_r;
    end
end

//----------------tvg_cnt------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        tvg_cnt <= 'd0;
    end
    else if(tvg_cnt == cycle_cnt_r - 1)begin
        tvg_cnt <= 'd0;
    end
    else begin
        tvg_cnt <= tvg_cnt + 1'b1;
    end
end

//---------------user_tx_data_start-------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        user_tx_data_start <= 1'b0;
    end
    else if(tvg_cnt == start_cnt_r - 1'b1)begin
        user_tx_data_start <= 1'b1;
    end
    else begin
        user_tx_data_start <= 1'b0;
    end
end

//---------------user_tx_data_end-------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        user_tx_data_end <= 1'b0;
    end
    else if(pkt_cnt == packet_cnt_r - 'd2)begin
        user_tx_data_end <= 1'b1;
    end
    else begin
        user_tx_data_end <= 1'b0;
    end
end

//----------------packetlength------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        packetlength <= 'd0;
    end
    // packet length include 4bytes crc
    else if(tvg_cnt == start_cnt_r - 1'b1) begin
        packetlength <= packet_cnt_r + 'd4;
    end
end

//----------------user_tx_data_valid------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        user_tx_data_valid <= 1'b0;
    end
    else if(user_tx_data_valid==1'b1 && pkt_cnt==packet_cnt_r-1'b1)begin
        user_tx_data_valid <= 1'b0;
    end
    else if(tvg_cnt == start_cnt_r - 1'b1)begin
        user_tx_data_valid <= 1'b1;
    end
end

//----------------pkt_cnt------------------
always @(posedge clk_User) begin
    if(reset == 1'b1)begin
        pkt_cnt <= 'd0;
    end
    else if(user_tx_data_valid==1'b1 && pkt_cnt==packet_cnt_r-1'b1)begin
        pkt_cnt <= 'd0;
    end
    else if (user_tx_data_valid == 1'b1) begin
        pkt_cnt <= pkt_cnt + 1'b1;
    end
end

assign user_tx_data = pkt_cnt[7:0];


    
endmodule
