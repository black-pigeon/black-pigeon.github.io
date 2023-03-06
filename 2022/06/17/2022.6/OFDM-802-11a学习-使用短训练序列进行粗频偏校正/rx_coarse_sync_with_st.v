// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : rx_coarse_sync_with_st
// Create 	 : 2022-05-30
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : rx coarse sync using shor training sequence
// 			   
// -----------------------------------------------------------------------------
module rx_coarse_sync_with_st (
    input   wire            clk                         ,
    input   wire            rst                         ,
    input   wire            enable                      ,
    input   wire    [15:0]  sample_in_i                 ,
    input   wire    [15:0]  sample_in_q                 ,
    input   wire            sample_in_valid             ,

    input   wire    [31:0]  sts_coarse_freq_offset_i    ,
    input   wire    [31:0]  sts_coarse_freq_offset_q    ,
    input   wire            sts_coarse_freq_offset_valid,   

    output  reg     [15:0]  sample_cfoc_i               ,// data after coarse freq offset
    output  reg     [15:0]  sample_cfoc_q               ,
    output  reg             sample_cfoc_valid                   
);


    //====================================================
    // internal signals and registers
    //====================================================
    wire            sample_delay_out_valid      ;
    wire  [15:0]    sample_delay_out_i, sample_delay_out_q; 
    reg   [15:0]    sample_delay_out_i_dly, sample_delay_out_q_dly;

    // fix point data 1bit sign, 3bit quotient, 28bit fractional
    wire  [31:0]    angle_out                   ; // actual estimate angle data
    wire            angle_out_valid             ;
    wire  [31:0]    angle_out_div16x2pi         ; // estimate angle data for drive dds
    wire            angle_out_div16x2pi_valid   ;

    reg   [31:0]    freq_control_word           ;
    reg   [31:0]    phase_accumulator           ;
    reg             phase_acc_valid             ;
    wire  [15:0]    dds_cfoc_i, dds_cfoc_q      ;
    wire            dds_cfoc_valid              ;

    wire            cmpy_cfoc_out_valid         ;
    wire  [31:0]    cmpy_cfoc_out_i, cmpy_cfoc_out_q;



    // delay input samples, after coarse freq offset is calculated out, 
    // correction freq could add to these samples
    sample_delay#(
        .DATA_WIDTH              ( 32 ),
        .DELAY_DEEPTH            ( 256 )
    )u_sample_delay(
        .clk                     ( clk                     ),
        .rst                     ( rst                     ),
        .enable                  ( enable                  ),
        .sample_in_valid         ( sample_in_valid         ),
        .sample_in               ( {sample_in_q, sample_in_i} ),
        .sample_delay_out_valid  ( sample_delay_out_valid  ),
        .sample_delay_out        ( {sample_delay_out_q, sample_delay_out_i})
    );


    fix_arctan u_fix_arctan(
        .clk                        ( clk                       ),
        .rst                        ( rst                       ),
        .enable                     ( enable                    ),
        .y_in                       ( sts_coarse_freq_offset_q  ),
        .x_in                       ( sts_coarse_freq_offset_i  ),
        .xy_in_valid                ( sts_coarse_freq_offset_valid),
        .angle_out                  ( angle_out                 ),
        .angle_out_valid            ( angle_out_valid           ),
        .angle_out_div16x2pi        ( angle_out_div16x2pi       ),
        .angle_out_div16x2pi_valid  ( angle_out_div16x2pi_valid  )
    );

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            freq_control_word <= 'd0;
        end
        else if (enable == 1'b1) begin
            freq_control_word <= {angle_out_div16x2pi, 4'd0};
        end
        else  begin
            freq_control_word <=  'd0;
        end
    end
    

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            phase_accumulator <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (sample_delay_out_valid == 1'b1) begin
                phase_accumulator <= phase_accumulator - freq_control_word;
            end
        end
        else  begin
            phase_accumulator <=  'd0;
        end
    end

    //----------------phase_acc_valid------------------
    always @(posedge clk) begin
        if (rst==1'b1) begin
            phase_acc_valid <= 1'b0;
        end
        else if (enable == 1'b1 && sample_delay_out_valid == 1'b1) begin
            phase_acc_valid <= 1'b1;
        end
        else  begin
            phase_acc_valid <=  1'b0;
        end
    end

    always @(posedge clk) begin
        {sample_delay_out_i_dly, sample_delay_out_q_dly} <= {sample_delay_out_i, sample_delay_out_q};
    end


    // 1 beat latency
    dds_cfoc u_dds_cfoc (
        .aclk(clk),                                // input wire aclk
        .s_axis_phase_tvalid(phase_acc_valid),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata({ {4{phase_accumulator[31]}},phase_accumulator[31:20]}),    // input wire [15 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(dds_cfoc_valid),    // output wire m_axis_data_tvalid
        .m_axis_data_tdata({dds_cfoc_q, dds_cfoc_i})      // output wire [31 : 0] m_axis_data_tdata
    );
    


    cmpy_cfoc u_cmpy_cfoc (
        .aclk(clk),                              // input wire aclk
        .s_axis_a_tvalid(dds_cfoc_valid),        // input wire s_axis_a_tvalid
        .s_axis_a_tdata({dds_cfoc_q, dds_cfoc_i}),          // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(dds_cfoc_valid),        // input wire s_axis_b_tvalid
        .s_axis_b_tdata({sample_delay_out_q_dly, sample_delay_out_i_dly}),          // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid(cmpy_cfoc_out_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata({cmpy_cfoc_out_q, cmpy_cfoc_out_i})    // output wire [63 : 0] m_axis_dout_tdata
    );

    //----------------sample_cfoc_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sample_cfoc_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            sample_cfoc_valid <= cmpy_cfoc_out_valid;
            // sample_cfoc_valid <= sample_delay_out_valid;
        end
        else  begin
            sample_cfoc_valid <=  'd0;
        end
    end

    //----------------sample_cfoc_i/q------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sample_cfoc_i <= 'd0;
            sample_cfoc_q <= 'd0;
        end
        else if (enable == 1'b1) begin
            sample_cfoc_i <= {cmpy_cfoc_out_i[31],cmpy_cfoc_out_i[26:12]};
            sample_cfoc_q <= {cmpy_cfoc_out_q[31],cmpy_cfoc_out_q[26:12]};
            // sample_cfoc_i <= sample_delay_out_i;
            // sample_cfoc_q <= sample_delay_out_q;
        end
        else  begin
            sample_cfoc_i <= 'd0;
            sample_cfoc_q <= 'd0;
        end
    end

endmodule