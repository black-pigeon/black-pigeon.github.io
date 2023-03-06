// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : ofdm_packet_detect
// Create 	 : 2022-05-19
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : 802.11a ofdm pakcet detect using STS
// 			   
// -----------------------------------------------------------------------------
module ofdm_packet_detect (
    input   wire                clk                     ,
    input   wire                rst                     ,
    input   wire                enable                  ,   
    input   wire    [15:0]      sample_in_i             ,
    input   wire    [15:0]      sample_in_q             ,
    input   wire                sample_in_valid         ,
    input   wire    [15:0]      sts_detect_threshold    , // decision threshold
    output  reg                 sts_detect_flag           // detected the ofdm short training sequence
    );

    //====================================================
    // delay path
    //====================================================
    // delay one short traning sequence(16 beates in this case)
    wire            sample_delay_out_valid;
    wire    [31:0]  sample_delay_out;
    wire    [15:0]  sample_delay_out_i, sample_delay_out_q;
    
    // get the Conjugate value of the 16 beats delay
    reg     [15:0]  sample_delay_conj_i, sample_delay_conj_q;
    reg             sample_delay_conj_valid;

    // delay the input data for cross correlation
    reg     [15:0]  sample_in_i_dly1, sample_in_i_dly2;
    reg     [15:0]  sample_in_q_dly1, sample_in_q_dly2;
    reg             sample_in_valid_dly1, sample_in_valid_dly2;

    // calculate the complex multiplication
    wire            s_delay_complex_out_valid;
    wire    [63:0]  s_delay_complex_out;
    wire    [31:0]  s_delay_complex_out_i, s_delay_complex_out_q;

    // calculate the accumulate value for cross correlation
    wire            s_delay_acc_avg_i_valid, s_delay_acc_avg_q_valid;
    wire    [31:0]  s_delay_acc_avg_i, s_delay_acc_avg_q;

    // get the absolute value of i/q for amplitude estimation
    reg             s_delay_est_abs_valid;
    reg     [31:0]  s_delay_est_abs_i, s_delay_est_abs_q;
    
    // get the max and min value of i/q for amplitude estimation
    reg             s_delay_est_max_min_valid;
    reg     [31:0]  s_delay_est_max, s_delay_est_min;

    // calculate the amplitude estimation 
    // mag = alpha*max(|I|, |Q|) + beta*min(|I|, |Q|);
    // alpha=1, beta=1/4
    reg             s_delay_amp_est_valid;
    reg     [31:0]  s_delay_amp_est;

    //====================================================
    // current path
    //====================================================

    // the conjugate value the current sample, this at the same beat 
    // of sample_in_i/q_dly2
    reg     [15:0]  s_curr_conj_q, s_curr_conj_i;
    reg             s_curr_conj_valid;

    // calculate the complex multiplication
    wire            s_curr_complex_out_valid;
    wire    [63:0]  s_curr_complex_out;
    wire    [31:0]  s_curr_complex_out_i, s_curr_complex_out_q;

    // calculate the accumulate value for auto-correlation
    wire            s_curr_acc_avg_i_valid, s_curr_acc_avg_q_valid;
    wire    [31:0]  s_curr_acc_avg_i, s_curr_acc_avg_q;

    // get the absolute value of i/q for amplitude estimation
    reg             s_curr_est_abs_valid;
    reg     [31:0]  s_curr_est_abs_i, s_curr_est_abs_q;
    
    // get the max and min value of i/q for amplitude estimation
    reg             s_curr_est_max_min_valid;
    reg     [31:0]  s_curr_est_max, s_curr_est_min;

    // calculate the amplitude estimation 
    // mag = alpha*max(|I|, |Q|) + beta*min(|I|, |Q|);
    // alpha=1, beta=1/4
    reg             s_curr_amp_est_valid;
    reg     [31:0]  s_curr_amp_est;
    wire    [31:0]  s_curr_amp_est_075; // 75% of current amplitude estimation value

    //====================================================
    // detect region
    //====================================================
    reg     [15:0]  pos_threshold, neg_threshold;
    reg     [15:0]  amp_est_threshold;
    reg     [15:0]  cnt_pos, cnt_neg;
    reg     [15:0]  cnt_est_ok;
        
    

    /*********************************************************
                        delay path
    *********************************************************/
    //======================================================
    // delay 16 samples for Cross correlation
    // the sample_delay_out has 1 beat delay from sample_in
    //======================================================
    sample_delay#(
        .DATA_WIDTH              ( 32 ),
        .DELAY_DEEPTH            ( 16 )
    )u_sample_delay(
        .clk                     ( clk                     ),
        .rst                     ( rst                     ),
        .enable                  ( enable                  ),
        .sample_in_valid         ( sample_in_valid         ),
        .sample_in               ( {sample_in_q, sample_in_i} ),
        .sample_delay_out_valid  ( sample_delay_out_valid  ),
        .sample_delay_out        ( sample_delay_out        )
    );
    assign sample_delay_out_q = sample_delay_out[31:16];
    assign sample_delay_out_i = sample_delay_out[15:0];

    //====================================================
    // Conjugate the sample
    // 1 beat latency
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sample_delay_conj_q <= 'd0;
            sample_delay_conj_i <= 'd0;
            sample_delay_conj_valid <= 1'b0;
        end
        else  begin
            sample_delay_conj_q <= ~sample_delay_out_q + 1;
            sample_delay_conj_i <= sample_delay_out_i;
            sample_delay_conj_valid <= sample_delay_out_valid;
        end
    end

    //====================================================
    // delay 2 beats of the input sample,
    // In order to be able to match the 
    // data with a delay of 16 sampling points 
    //====================================================
    always @(posedge clk) begin
        if(rst == 1'b1)begin
            sample_in_i_dly1 <= 'd0;
            sample_in_i_dly2 <= 'd0;
            sample_in_q_dly1 <= 'd0;
            sample_in_q_dly2 <= 'd0;
            sample_in_valid_dly1 <= 'd0;
            sample_in_valid_dly2 <= 'd0;
        end
        else begin
            sample_in_i_dly1 <= sample_in_i;
            sample_in_i_dly2 <= sample_in_i_dly1;
            sample_in_q_dly1 <= sample_in_q;
            sample_in_q_dly2 <= sample_in_q_dly1;
            sample_in_valid_dly1 <= sample_in_valid;
            sample_in_valid_dly2 <= sample_in_valid_dly1; 
        end
    end

    //====================================================
    // complex multiplication, conj(s[i])*s[i+16]
    // 4 beats latency
    //====================================================
    cmpy_iq16 u_cmpy_iq16_packet_detect_delay (
        .aclk(clk),                              // input wire aclk
        .s_axis_a_tvalid(sample_delay_conj_valid),        // input wire s_axis_a_tvalid
        .s_axis_a_tdata({sample_delay_conj_q, sample_delay_conj_i}),          // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(sample_delay_conj_valid),        // input wire s_axis_b_tvalid
        .s_axis_b_tdata({sample_in_q_dly2, sample_in_i_dly2}),          // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid(s_delay_complex_out_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(s_delay_complex_out)    // output wire [63 : 0] m_axis_dout_tdata
    );

    assign s_delay_complex_out_i = s_delay_complex_out[31:0];
    assign s_delay_complex_out_q = s_delay_complex_out[63:32];

    //====================================================
    // calculate the 16 sample accumulate value
    // 3 beats latency
    //====================================================
    accumulate_avg#(
        .DATA_WIDTH         ( 32 ),
        .DELAY_DEEPTH       ( 16 )
    )u_acc_avg_delay_i(
        .clk                ( clk                       ),
        .rst                ( rst                       ),
        .enable             ( enable                    ),
        .sample_in_valid    ( s_delay_complex_out_valid ),
        .sample_in          ( s_delay_complex_out_i     ),
        .acc_avg_out_valid  ( s_delay_acc_avg_i_valid   ),
        .acc_avg_out        ( s_delay_acc_avg_i         )
    );

    accumulate_avg#(
        .DATA_WIDTH         ( 32 ),
        .DELAY_DEEPTH       ( 16 )
    )u_acc_avg_delay_q(
        .clk                ( clk                       ),
        .rst                ( rst                       ),
        .enable             ( enable                    ),
        .sample_in_valid    ( s_delay_complex_out_valid ),
        .sample_in          ( s_delay_complex_out_q     ),
        .acc_avg_out_valid  ( s_delay_acc_avg_q_valid   ),
        .acc_avg_out        ( s_delay_acc_avg_q         )
    );

    //====================================================
    // Amplitude estimation, step 1:
    // get the absolute value of i/q data
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_delay_est_abs_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            s_delay_est_abs_valid <= s_delay_acc_avg_i_valid; 
        end
        else  begin
            s_delay_est_abs_valid <=  1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_delay_est_abs_i <= 'd0;
            s_delay_est_abs_q <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_delay_acc_avg_i_valid == 1'b1) begin
                s_delay_est_abs_i <= s_delay_acc_avg_i[31]? ~(s_delay_acc_avg_i)+1 : s_delay_acc_avg_i;
                s_delay_est_abs_q <= s_delay_acc_avg_q[31]? ~(s_delay_acc_avg_q)+1 : s_delay_acc_avg_q;
            end
        end
        else  begin
            s_delay_est_abs_i <= 'd0;
            s_delay_est_abs_q <= 'd0;
        end
    end

    //====================================================
    // Amplitude estimation, step 2:
    // get the max and min value of |I|, |Q|
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_delay_est_max_min_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            s_delay_est_max_min_valid <= s_delay_est_abs_valid; 
        end
        else  begin
            s_delay_est_max_min_valid <=  1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_delay_est_max <= 'd0;
            s_delay_est_min <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_delay_est_abs_valid == 1'b1) begin
                s_delay_est_max <= (s_delay_est_abs_i > s_delay_est_abs_q) ? s_delay_est_abs_i : s_delay_est_abs_q;
                s_delay_est_min <= (s_delay_est_abs_i < s_delay_est_abs_q) ? s_delay_est_abs_i : s_delay_est_abs_q;
            end
        end
        else  begin
            s_delay_est_max <= 'd0;
            s_delay_est_min <= 'd0;
        end
    end   

    //====================================================
    // Amplitude estimation, step 3:
    // calculate the amplitude estimation 
    // mag = alpha*max(|I|, |Q|) + beta*min(|I|, |Q|);
    // alpha=1, beta=1/4
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_delay_amp_est_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            s_delay_amp_est_valid <= s_delay_est_max_min_valid; 
        end
        else  begin
            s_delay_amp_est_valid <=  1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_delay_amp_est <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_delay_est_abs_valid == 1'b1) begin
                s_delay_amp_est <= s_delay_est_max + s_delay_est_min[31:2];
            end
        end
        else  begin
            s_delay_amp_est <= 'd0;
        end
    end      

    //====================================================
    // get the conjugate value of current samples
    //====================================================
    always @(posedge clk) begin
        if(rst == 1'b1)begin
            s_curr_conj_q <= 'd0;
            s_curr_conj_i <= 'd0;
            s_curr_conj_valid <= 1'b0;
        end
        else begin
            s_curr_conj_valid <= sample_in_valid_dly1;
            s_curr_conj_i <= sample_in_i_dly1;
            s_curr_conj_q <= ~sample_in_q_dly1 + 1;
        end
    end

    /*********************************************************
                        current path
    *********************************************************/
    //====================================================
    // complex multiplication, conj(s[i])*s[i]
    // 4 beats latency
    //====================================================
    cmpy_iq16 u_cmpy_iq16_packet_detect_curr (
        .aclk(clk),                              // input wire aclk
        .s_axis_a_tvalid(s_curr_conj_valid),        // input wire s_axis_a_tvalid
        .s_axis_a_tdata({s_curr_conj_q, s_curr_conj_i}),          // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(s_curr_conj_valid),        // input wire s_axis_b_tvalid
        .s_axis_b_tdata({sample_in_q_dly2, sample_in_i_dly2}),          // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid(s_curr_complex_out_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(s_curr_complex_out)    // output wire [63 : 0] m_axis_dout_tdata
    );

    assign s_curr_complex_out_i = s_curr_complex_out[31:0];
    assign s_curr_complex_out_q = s_curr_complex_out[63:32];

    //====================================================
    // calculate the 16 sample accumulate value
    // 3 beats latency
    //====================================================
    accumulate_avg#(
        .DATA_WIDTH         ( 32 ),
        .DELAY_DEEPTH       ( 16 )
    )u_acc_avg_curr_i(
        .clk                ( clk                       ),
        .rst                ( rst                       ),
        .enable             ( enable                    ),
        .sample_in_valid    ( s_curr_complex_out_valid ),
        .sample_in          ( s_curr_complex_out_i     ),
        .acc_avg_out_valid  ( s_curr_acc_avg_i_valid   ),
        .acc_avg_out        ( s_curr_acc_avg_i         )
    );

    accumulate_avg#(
        .DATA_WIDTH         ( 32 ),
        .DELAY_DEEPTH       ( 16 )
    )u_acc_avg_curr_q(
        .clk                ( clk                       ),
        .rst                ( rst                       ),
        .enable             ( enable                    ),
        .sample_in_valid    ( s_curr_complex_out_valid ),
        .sample_in          ( s_curr_complex_out_q     ),
        .acc_avg_out_valid  ( s_curr_acc_avg_q_valid   ),
        .acc_avg_out        ( s_curr_acc_avg_q         )
    );

    //====================================================
    // Amplitude estimation, step 1:
    // get the absolute value of i/q data
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_curr_est_abs_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            s_curr_est_abs_valid <= s_curr_acc_avg_i_valid; 
        end
        else  begin
            s_curr_est_abs_valid <=  1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_curr_est_abs_i <= 'd0;
            s_curr_est_abs_q <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_curr_acc_avg_i_valid == 1'b1) begin
                s_curr_est_abs_i <= s_curr_acc_avg_i[31]? ~(s_curr_acc_avg_i)+1 : s_curr_acc_avg_i;
                s_curr_est_abs_q <= s_curr_acc_avg_q[31]? ~(s_curr_acc_avg_q)+1 : s_curr_acc_avg_q;
            end
        end
        else  begin
            s_curr_est_abs_i <= 'd0;
            s_curr_est_abs_q <= 'd0;
        end
    end

    //====================================================
    // Amplitude estimation, step 2:
    // get the max and min value of |I|, |Q|
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_curr_est_max_min_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            s_curr_est_max_min_valid <= s_curr_est_abs_valid; 
        end
        else  begin
            s_curr_est_max_min_valid <=  1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_curr_est_max <= 'd0;
            s_curr_est_min <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_curr_est_abs_valid == 1'b1) begin
                s_curr_est_max <= (s_curr_est_abs_i > s_curr_est_abs_q) ? s_curr_est_abs_i : s_curr_est_abs_q;
                s_curr_est_min <= (s_curr_est_abs_i < s_curr_est_abs_q) ? s_curr_est_abs_i : s_curr_est_abs_q;
            end
        end
        else  begin
            s_curr_est_max <= 'd0;
            s_curr_est_min <= 'd0;
        end
    end   

    //====================================================
    // Amplitude estimation, step 3:
    // calculate the amplitude estimation 
    // mag = alpha*max(|I|, |Q|) + beta*min(|I|, |Q|);
    // alpha=1, beta=1/4
    //====================================================
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_curr_amp_est_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            s_curr_amp_est_valid <= s_curr_est_max_min_valid; 
        end
        else  begin
            s_curr_amp_est_valid <=  1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            s_curr_amp_est <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_curr_est_abs_valid == 1'b1) begin
                s_curr_amp_est <= s_curr_est_max + s_curr_est_min[31:2];
            end
        end
        else  begin
            s_curr_amp_est <= 'd0;
        end
    end

    assign s_curr_amp_est_075 = s_curr_amp_est[31:2] + s_curr_amp_est[31:1];

    /*********************************************************
                        detect region
    *********************************************************/
        
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            pos_threshold <= 'd0;
            neg_threshold <= 'd0;
            amp_est_threshold <= 'd0;
        end
        else if (enable) begin
            pos_threshold <= sts_detect_threshold >> 2;
            neg_threshold <= sts_detect_threshold >> 2;
            amp_est_threshold <= sts_detect_threshold ;
        end
        else  begin
            pos_threshold <=  'd0;
            neg_threshold <= 'd0;
            amp_est_threshold <= 'd0;
        end
    end

    //----------------cnt_est_ok------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_est_ok <= 'd0;
        end
        else if (enable == 1'b1) begin
            // detect the sequence
            if (s_delay_amp_est_valid == 1'b1 && s_delay_amp_est > s_curr_amp_est_075 && cnt_est_ok == amp_est_threshold) begin
                cnt_est_ok <= 'd0;
            end
            else if (s_delay_amp_est_valid == 1'b1 && s_delay_amp_est > s_curr_amp_est_075) begin
                cnt_est_ok <= cnt_est_ok + 1'b1;
            end
            else if (s_delay_amp_est_valid == 1'b1 && s_delay_amp_est <= s_curr_amp_est_075) begin
                cnt_est_ok <= 'd0;
            end
        end
        else  begin
            cnt_est_ok <=  'd0;
        end
    end

    //----------------cnt_pos/cnt_neg------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_pos <= 'd0;
            cnt_neg <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (s_delay_amp_est_valid == 1'b1 && s_delay_amp_est > s_curr_amp_est_075) begin
                if (sample_in_i[15]) begin
                    cnt_neg <= cnt_neg + 1'b1;
                end
                else begin
                    cnt_pos <= cnt_pos + 1'b1;
                end
            end
            else if (s_delay_amp_est_valid == 1'b1 && s_delay_amp_est <= s_curr_amp_est_075) begin
                cnt_neg <= 'd0;
                cnt_pos <= 'd0;
            end
        end
        else  begin
            cnt_pos <=  'd0;
            cnt_neg <= 'd0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sts_detect_flag <= 1'b0;
        end
        else if (s_delay_amp_est_valid == 1'b1 && s_delay_amp_est > s_curr_amp_est_075 && cnt_est_ok == amp_est_threshold) begin
            if (cnt_pos > pos_threshold && cnt_neg > neg_threshold) begin
                sts_detect_flag <= 1'b1;
            end
            else begin
                sts_detect_flag <= 1'b0;
            end
        end
        else begin
            sts_detect_flag <= 1'b0;
        end
    end
    
endmodule