// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : Rx802_11a_Top
// Create 	 : 2022-05-19
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : 802.11a rx top module
// 			   
// -----------------------------------------------------------------------------

module Rx802_11a_Top (
    input   wire                clk                     ,
    input   wire                rst                     ,
    input   wire                enable                  ,   
    input   wire    [15:0]      sample_in_i             ,
    input   wire    [15:0]      sample_in_q             ,
    input   wire                sample_in_valid         ,
    input   wire    [15:0]      sts_detect_threshold    , // decision threshold
    output  wire                sts_detect_flag           // detected the ofdm short training sequence
    );


    ofdm_packet_detect u_ofdm_packet_detect(
        .clk                   ( clk                   ),
        .rst                   ( rst                   ),
        .enable                ( enable                ),
        .sample_in_i           ( sample_in_i           ),
        .sample_in_q           ( sample_in_q           ),
        .sample_in_valid       ( sample_in_valid       ),
        .sts_detect_threshold  ( sts_detect_threshold  ),
        .sts_detect_flag       ( sts_detect_flag       )
    );


endmodule