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

    //====================================================
    // parameter define
    //====================================================
    localparam IDLE         = 8'b0000_0001;
    localparam DETECT_STS   = 8'b0000_0010;
    localparam DETECT_LTS   = 8'b0000_0100;

    localparam LTS_DETECT_THRESHOLD = 25000;


    //====================================================
    //internal signals and registers    
    //====================================================
    reg     [7:0]   state                           ;
    wire            sts_detect_enable               ;
    wire            lts_detect_eanble               ;

    // rx_coarse_sync_with_st Outputs       
    wire   [31:0]   sts_coarse_freq_offset_i        ;
    wire   [31:0]   sts_coarse_freq_offset_q        ;
    wire            sts_coarse_freq_offset_valid    ;

    // rx_coarse_sync_with_st Outputs
    wire  [15:0]    sample_cfoc_i                   ;
    wire  [15:0]    sample_cfoc_q                   ;
    wire            sample_cfoc_valid               ;

    // lts_detect_align Outputs
    wire            align_lts1_valid                ;
    wire  [15:0]    align_lts1_i                    ;
    wire  [15:0]    align_lts1_q                    ;
    wire            acc_avg_valid                   ;
    wire  [15:0]    acc_avg_i                       ;
    wire  [15:0]    acc_avg_q                       ;
    wire            detect_lts_status               ;
    wire            detect_lts_status_valid         ;

    // rx_fine_sync_with_lts Outputs
    wire            sample_fine_foc_valid;
    wire  [15:0]    sample_fine_foc_i;
    wire  [15:0]    sample_fine_foc_q;





    assign sts_detect_enable = (state == DETECT_STS) ? 1'b1 : 1'b0;
    assign lts_detect_eanble = (state == DETECT_LTS) ? 1'b1 : 1'b0;

    //----------------state------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= IDLE ;
        end
        else if (enable == 1'b1) begin
            case (state)
                IDLE: begin
                    state <= DETECT_STS;
                end

                DETECT_STS : begin
                    if (sts_coarse_freq_offset_valid == 1'b1) begin
                        state <= DETECT_LTS;
                    end
                end

                DETECT_LTS : begin
                    // error occured
                    if (detect_lts_status == 1'b1) begin
                        state <= IDLE;
                    end
                end
                
            endcase
        end
        else  begin
            state <= IDLE;
        end
    end


    ofdm_packet_detect u_ofdm_packet_detect(
        .clk                            ( clk                           ),
        .rst                            ( rst                           ),
        .enable                         ( enable & sts_detect_enable    ),
        .sample_in_i                    ( sample_in_i                   ),
        .sample_in_q                    ( sample_in_q                   ),
        .sample_in_valid                ( sample_in_valid               ),
        .sts_detect_threshold           ( sts_detect_threshold          ),
        .sts_detect_flag                ( sts_detect_flag               ),
        .sts_coarse_freq_offset_i       ( sts_coarse_freq_offset_i      ),        
        .sts_coarse_freq_offset_q       ( sts_coarse_freq_offset_q      ),
        .sts_coarse_freq_offset_valid   ( sts_coarse_freq_offset_valid  ) 

    );

    rx_coarse_sync_with_st  u_rx_coarse_sync_with_st (
        .clk                           ( clk                            ),
        .rst                           ( rst                            ),
        .enable                        ( enable                         ),
        .sample_in_i                   ( sample_in_i                    ),
        .sample_in_q                   ( sample_in_q                    ),
        .sample_in_valid               ( sample_in_valid                ),
        .sts_coarse_freq_offset_i      ( sts_coarse_freq_offset_i       ),
        .sts_coarse_freq_offset_q      ( sts_coarse_freq_offset_q       ),
        .sts_coarse_freq_offset_valid  ( sts_coarse_freq_offset_valid   ),

        .sample_cfoc_i                 ( sample_cfoc_i                  ),
        .sample_cfoc_q                 ( sample_cfoc_q                  ),
        .sample_cfoc_valid             ( sample_cfoc_valid              )
    );

    lts_detect_align  u_lts_detect_align (
        .clk                      ( clk                       ),
        .rst                      ( rst                       ),
        .enable                   ( enable & lts_detect_eanble),
        .lts_threshold            ( LTS_DETECT_THRESHOLD      ),
        .sample_in_valid          ( sample_cfoc_valid         ),
        .sample_in_i              ( sample_cfoc_i             ),
        .sample_in_q              ( sample_cfoc_q             ),

        .align_lts1_valid         ( align_lts1_valid          ),
        .align_lts1_i             ( align_lts1_i              ),
        .align_lts1_q             ( align_lts1_q              ),
        .acc_avg_valid            ( acc_avg_valid             ),
        .acc_avg_i                ( acc_avg_i                 ),
        .acc_avg_q                ( acc_avg_q                 ),
        .detect_lts_status        ( detect_lts_status         ),
        .detect_lts_status_valid  ( detect_lts_status_valid   )
    );

    rx_fine_sync_with_lts  u_rx_fine_sync_with_lts (
        .clk                      ( clk                       ),
        .rst                      ( rst                       ),
        .enable                   ( enable & lts_detect_eanble),
        .sample_in_i              ( sample_cfoc_i             ),
        .sample_in_q              ( sample_cfoc_q             ),
        .sample_in_valid          ( sample_cfoc_valid         ),
        .detect_lts_status        ( detect_lts_status         ),
        .detect_lts_status_valid  ( detect_lts_status_valid   ),
        .align_lts1_valid         ( align_lts1_valid          ),
        .align_lts1_i             ( align_lts1_i              ),
        .align_lts1_q             ( align_lts1_q              ),

        .sample_fine_foc_valid    ( sample_fine_foc_valid     ),
        .sample_fine_foc_i        ( sample_fine_foc_i         ),
        .sample_fine_foc_q        ( sample_fine_foc_q         )
    );

endmodule