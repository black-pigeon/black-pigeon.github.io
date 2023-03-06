// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : lts_detect_align
// Create 	 : 2022-06-07
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : detect long training sequence, and align the output to the LTS
// 			   
// -----------------------------------------------------------------------------
module lts_detect_align(
    input   wire            clk                     ,
    input   wire            rst                     ,
    input   wire            enable                  ,
    input   wire    [15:0]  lts_threshold           ,
    input   wire            sample_in_valid         ,
    input   wire    [15:0]  sample_in_i             ,
    input   wire    [15:0]  sample_in_q             ,

    output  wire            align_lts1_valid        ,
    output  wire    [15:0]  align_lts1_i            ,
    output  wire    [15:0]  align_lts1_q            ,

    output  wire            acc_avg_valid           ,
    output  wire    [15:0]  acc_avg_i               ,
    output  wire    [15:0]  acc_avg_q               ,

    output  reg             detect_lts_status       ,//0 ok, 1 error
    output  reg             detect_lts_status_valid
);

    wire                lts_cross_corr_valid    ;
    wire    [31:0]      lts_cross_corr          ;
    
    wire                sample_delay_out_valid  ;
    wire    [15:0]      sample_delay_out_i      ;
    wire    [15:0]      sample_delay_out_q      ;

    reg     [15:0]      sample_delay_out_i_dly0 ;
    reg     [15:0]      sample_delay_out_i_dly1 ;
    reg     [15:0]      sample_delay_out_i_dly2 ;
    reg     [15:0]      sample_delay_out_i_dly3 ;
    reg     [15:0]      sample_delay_out_i_dly4 ;

    reg     [15:0]      sample_delay_out_q_dly0 ;
    reg     [15:0]      sample_delay_out_q_dly1 ;
    reg     [15:0]      sample_delay_out_q_dly2 ;
    reg     [15:0]      sample_delay_out_q_dly3 ;
    reg     [15:0]      sample_delay_out_q_dly4 ;


    reg                 sample_delay_out_v_dly0 ;
    reg                 sample_delay_out_v_dly1 ;
    reg                 sample_delay_out_v_dly2 ;
    reg                 sample_delay_out_v_dly3 ;
    reg                 sample_delay_out_v_dly4 ;


    reg     [15:0]      cnt_sample              ;
    reg     [15:0]      peak_position1          ;
    reg     [15:0]      peak_position2          ;
    reg     [2:0]       cnt_peak                ;
    reg                 detect_2peak_flag       ;
    


    //======================================================
    // delay 96 samples for Cross correlation
    // the sample_delay_out has 1 system clock delay from sample_in
    //======================================================
    sample_delay#(
        .DATA_WIDTH              ( 32 ),
        .DELAY_DEEPTH            ( 96 )
    )u_sample_delay(
        .clk                     ( clk                                      ),
        .rst                     ( rst                                      ),
        .enable                  ( enable                                   ),
        .sample_in_valid         ( sample_in_valid                          ),
        .sample_in               ( {sample_in_q, sample_in_i}               ),
        .sample_delay_out_valid  ( sample_delay_out_valid                   ),
        .sample_delay_out        ( {sample_delay_out_q, sample_delay_out_i} )
    );


    always @(posedge clk) begin
        sample_delay_out_i_dly0 <= sample_delay_out_i       ;
        sample_delay_out_i_dly1 <= sample_delay_out_i_dly0  ;
        sample_delay_out_i_dly2 <= sample_delay_out_i_dly1  ;
        sample_delay_out_i_dly3 <= sample_delay_out_i_dly2  ;
        sample_delay_out_i_dly4 <= sample_delay_out_i_dly3  ;

        sample_delay_out_q_dly0 <= sample_delay_out_q       ;
        sample_delay_out_q_dly1 <= sample_delay_out_q_dly0  ;
        sample_delay_out_q_dly2 <= sample_delay_out_q_dly1  ;
        sample_delay_out_q_dly3 <= sample_delay_out_q_dly2  ;
        sample_delay_out_q_dly4 <= sample_delay_out_q_dly3  ;

        sample_delay_out_v_dly0 <= sample_delay_out_valid   ;
        sample_delay_out_v_dly1 <= sample_delay_out_v_dly0  ;
        sample_delay_out_v_dly2 <= sample_delay_out_v_dly1  ;
        sample_delay_out_v_dly3 <= sample_delay_out_v_dly2  ;
        sample_delay_out_v_dly4 <= sample_delay_out_v_dly3  ;
    end

    //====================================================
    // cross correlation of LTS
    // output data is 7 system clock latency
    //====================================================
    long_training_seq_cross_corr u_long_training_seq_cross_corr(
        .clk                    ( clk              ),
        .rst                    ( rst              ),
        .enable                 ( enable           ),
        .sample_in_valid        ( sample_in_valid  ),
        .sample_in_i            ( sample_in_i      ),
        .sample_in_q            ( sample_in_q      ),
        .lts_cross_corr         ( lts_cross_corr   ),
        .lts_cross_corr_valid   ( lts_cross_corr_valid  )
    );

    //----------------cnt_sample------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_sample <= 'd0;
        end
        else if (enable == 1'b1 ) begin
            if (detect_lts_status == 1'b1) begin
                cnt_sample <=  'd0;
            end
            else if (detect_2peak_flag == 1'b1) begin
                cnt_sample <=  'd0;
            end
            else if (lts_cross_corr_valid == 1'b1) begin
                cnt_sample <= cnt_sample + 1'b1;
            end
        end
        else begin
            cnt_sample <=  'd0;
        end
    end

    //----------------cnt_peak------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_peak <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (cnt_peak >= 'd2) begin
                cnt_peak <= 'd0;
            end
            else if (lts_cross_corr_valid == 1'b1 && lts_cross_corr >= lts_threshold) begin
                cnt_peak <= cnt_peak + 1'b1;
            end
        end
        else  begin
            cnt_peak <=  'd0;
        end
    end

    //----------------peak_position1,2------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            peak_position1 <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (lts_cross_corr_valid == 1'b1 && lts_cross_corr >= lts_threshold && cnt_peak == 'd0) begin
                peak_position1 <= cnt_sample;
            end
        end
        else  begin
            peak_position1 <= 'd0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            peak_position2 <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (lts_cross_corr_valid == 1'b1 && lts_cross_corr >= lts_threshold && cnt_peak == 'd1) begin
                peak_position2 <= cnt_sample;
            end
        end
        else  begin
            peak_position2 <= 'd0;
        end
    end

    //----------------detect_2peak_flag------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            detect_2peak_flag <= 1'b0;
        end
        else if (enable) begin
            if (cnt_peak == 'd2 && (peak_position2 - peak_position1) >= 63 && (peak_position2 - peak_position1) <= 65) begin
                detect_2peak_flag <= 1'b1;
            end
        end
        else  begin
            detect_2peak_flag <=  1'b0;
        end
    end

    assign align_lts1_valid = detect_2peak_flag ? sample_delay_out_v_dly4 : 1'b0;
    assign align_lts1_i = detect_2peak_flag ? sample_delay_out_i_dly4 : 'd0;
    assign align_lts1_q = detect_2peak_flag ? sample_delay_out_q_dly4 : 'd0;

    //-----------------detect_lts_status-----------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            detect_lts_status <= 1'b0;
        end
        else if (enable == 1'b1) begin
            if (cnt_sample == 'd1023 && lts_cross_corr_valid == 1'b1) begin
                detect_lts_status <= 1'b1;
            end
            else if (cnt_peak == 'd2 && (peak_position2 - peak_position1) >= 63 && (peak_position2 - peak_position1) <= 65) begin
                detect_lts_status <= 1'b0;
            end
        end
        else  begin
            detect_lts_status <=  1'b0;
        end
    end

    //----------------detect_lts_status_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            detect_lts_status_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            if (cnt_sample == 'd1023 && lts_cross_corr_valid == 1'b1) begin
                detect_lts_status_valid <= 1'b1;
            end
            else if (cnt_peak == 'd2 && (peak_position2 - peak_position1) >= 63 && (peak_position2 - peak_position1) <= 65) begin
                detect_lts_status_valid <= 1'b1;
            end
            else begin
                detect_lts_status_valid <= 1'b0;
            end
        end
        else begin
            detect_lts_status_valid <=  1'b0;
        end
    end
    
endmodule