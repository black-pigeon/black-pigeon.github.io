`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/06/06 15:59:30
// Design Name: 
// Module Name: tb_demo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
//`define DATAFROMFILE 1


module tb_demo3();

	// clock
	reg clk_20MHz = 0;
	reg clk_100MHz = 0;
	reg clk_200MHz = 0;
	always #25	clk_20MHz	= ~clk_20MHz;
	always #5	clk_100MHz	= ~clk_100MHz;
	always #2.5	clk_200MHz	= ~clk_200MHz;

	reg clk_User = 0;
	reg clk_Modulation = 0;
	always #100  clk_User  = ~clk_User;
	always #12.5 clk_Modulation = ~clk_Modulation;

	// synchronous reset
	reg sysrst_n;
	initial begin
		sysrst_n <= 'b0;
		repeat(100)@(posedge clk_100MHz);
		sysrst_n <= 'b1;
	end

	//-------------------------------
	wire		tx_802p11_out_valid;	//802p11调制数据有效
	wire [15:0]	tx_802p11_re_out;		//802p11 re调制数据
	wire [15:0]	tx_802p11_im_out;		//802p11 im调制数据
	//debug					
	wire 		tx_generate_data_valid;
	wire 		tx_generate_data_bit;
	wire 		scramble_lc_bit_valid;
	wire 		scramble_lc_bit;
	wire 		tx_conv_encoder_valid;
	wire [ 1:0]	tx_conv_encoder_bit;
	wire 		tx_puncture_valid;
	wire 		tx_puncture_bit;
	wire 		tx_interleaver_intlvr_patt_valid;
	wire [15:0]	tx_interleaver_intlvr_patt;
	wire		tx_interleaver_bit_valid;
	wire		tx_interleaver_bit;
	wire		tx_add_cyclic_prefix_valid;
	wire [15:0]	tx_add_cyclic_prefix_re;
	wire [15:0]	tx_add_cyclic_prefix_im;
	//sig gen debug		
	wire		tx_gen_pkt_sig_valid;
	wire		tx_gen_pkt_sig_out;
	wire		tx_gen_pkt_sig_conv_valid;
	wire [ 1:0]	tx_gen_pkt_sig_conv_bit;
	wire		tx_gen_sig_interleaver_valid;
	wire		tx_gen_sig_interleaver_bit;
	wire		tx_gen_sig_add_cyclic_prefix_valid;
	wire [15:0]	tx_gen_sig_add_cyclic_prefix_re;
	wire [15:0]	tx_gen_sig_add_cyclic_prefix_im;
	//-------------------------------    

	reg  [15:0]	file_i1 = 0, file_q1 = 0;
	reg  [15:0]	sample_i = 0,sample_q = 0;
	integer board_tx_802p11_iq_fd;
	
	// add ports for register based inputs
	wire [10:0] power_thres;
	wire [31:0] min_plateau;

	// INPUT: RSSI
	wire [10:0] rssi_half_db;
	// INPUT: I/Q sample
	reg  [31:0] sample_in;
	wire sample_in_strobe;
	wire soft_decoding;


	reg  [ 3:0]	cnt_samp = 0;

	// OUTPUT: bytes and FCS status
	wire		demod_is_ongoing;
	wire		pkt_begin;
	wire		pkt_ht;
	wire		pkt_header_valid;
	wire		pkt_header_valid_strobe;
	wire		ht_unsupport;
	wire [ 7:0]	pkt_rate;
	wire [15:0]	pkt_len;
	wire [15:0]	pkt_len_total;
	wire 		byte_out_strobe;
	wire [ 7:0]	byte_reversed;
	wire [ 7:0]	byte_out;
	wire [15:0]	byte_count_total;
	wire [15:0]	byte_count;
	wire 		fcs_out_strobe;
	wire 		fcs_ok;

	// decode status
	// (* mark_debug = "true", DONT_TOUCH = "TRUE" *) 
	wire [ 3:0]	state;
	wire [ 3:0]	status_code;
	wire 		state_changed;
	wire [31:0]	state_history;

	// power trigger
	wire		power_trigger;

	// sync short
	wire		short_preamble_detected;
	wire [31:0] phase_offset;

	// sync long
	wire [31:0]	sync_long_metric;
	wire 		sync_long_metric_stb;
	wire 		long_preamble_detected;
	wire [31:0]	sync_long_out;
	wire 		sync_long_out_strobe;
	wire [31:0]	phase_offset_taken;
	wire [ 2:0]	sync_long_state;

	// equalizer
	wire [31:0]	equalizer_out;
	wire 		equalizer_out_strobe;
	wire [ 2:0]	equalizer_state;
	wire 		ofdm_symbol_eq_out_pulse;

	// legacy signal info
	wire 		legacy_sig_stb;
	wire [ 3:0]	legacy_rate;
	wire 		legacy_sig_rsvd;
	wire [11:0]	legacy_len;
	wire 		legacy_sig_parity;
	wire 		legacy_sig_parity_ok;
	wire [ 5:0]	legacy_sig_tail;

	// ht signal info
	wire 		ht_sig_stb;
	wire [ 6:0]	ht_mcs;
	wire 		ht_cbw;
	wire [15:0]	ht_len;
	wire 		ht_smoothing;
	wire 		ht_not_sounding;
	wire 		ht_aggregation;
	wire [ 1:0]	ht_stbc;
	wire 		ht_fec_coding;
	wire 		ht_sgi;
	wire [ 1:0]	ht_num_ext;
	wire 		ht_sig_crc_ok;

	// decoding pipeline
	wire [ 5:0]	demod_out;
	wire 		demod_out_strobe;

	wire [ 7:0]	deinterleave_erase_out;
	wire 		deinterleave_erase_out_strobe;

	wire 		conv_decoder_out;
	wire 		conv_decoder_out_stb;

	wire 		descramble_out;
	wire 		descramble_out_strobe;

	// for side channel
	wire [31:0]	csi;
	wire 		csi_valid;

`ifdef DATAFROMFILE
	integer tx_802p11_iq_fd;
	//-----------------------------------------
	initial begin
		board_tx_802p11_iq_fd	= $fopen("D:/RadioClass/OFDM/project_y230_7020_9363/ofdm802_11/xsa/adc_iq1.txt", "r");
		tx_802p11_iq_fd			= $fopen("D:/RadioClass/OFDM/project_y220_7010_9363/tx802p11_20210613/ofdm802.11/fpga_data/tx_802p11_iq_out2.txt", "w");
	 end


	always @(posedge clk_Modulation) begin 
		if(tx_802p11_out_valid) begin
			$fwrite(tx_802p11_iq_fd, "%d %d\n", $signed(tx_802p11_re_out),$signed(tx_802p11_im_out));
			$fflush(tx_802p11_iq_fd);
		end
	 end
`endif

	Tx802p11_Top inst_Tx802p11_Top (
		.clk_User                           (clk_User							),
		.clk_Modulation                     (clk_Modulation						),
		.reset                              (~sysrst_n							),
		.tx_802p11_out_valid                (tx_802p11_out_valid				),
		.tx_802p11_re_out                   (tx_802p11_re_out					),
		.tx_802p11_im_out                   (tx_802p11_im_out					),
		.tx_generate_data_valid             (tx_generate_data_valid				),
		.tx_generate_data_bit               (tx_generate_data_bit				),
		.scramble_lc_bit_valid              (scramble_lc_bit_valid				),
		.scramble_lc_bit                    (scramble_lc_bit					),
		.tx_conv_encoder_valid              (tx_conv_encoder_valid				),
		.tx_conv_encoder_bit                (tx_conv_encoder_bit				),
		.tx_puncture_valid                  (tx_puncture_valid					),
		.tx_puncture_bit                    (tx_puncture_bit					),
		.tx_interleaver_intlvr_patt_valid   (tx_interleaver_intlvr_patt_valid	),
		.tx_interleaver_intlvr_patt         (tx_interleaver_intlvr_patt			),
		.tx_interleaver_bit_valid           (tx_interleaver_bit_valid			),
		.tx_interleaver_bit                 (tx_interleaver_bit					),
		.tx_add_cyclic_prefix_valid         (tx_add_cyclic_prefix_valid			),
		.tx_add_cyclic_prefix_re            (tx_add_cyclic_prefix_re			),
		.tx_add_cyclic_prefix_im            (tx_add_cyclic_prefix_im			),
		.tx_gen_pkt_sig_valid               (tx_gen_pkt_sig_valid				),
		.tx_gen_pkt_sig_out                 (tx_gen_pkt_sig_out					),
		.tx_gen_pkt_sig_conv_valid          (tx_gen_pkt_sig_conv_valid			),
		.tx_gen_pkt_sig_conv_bit            (tx_gen_pkt_sig_conv_bit			),
		.tx_gen_sig_interleaver_valid       (tx_gen_sig_interleaver_valid		),
		.tx_gen_sig_interleaver_bit         (tx_gen_sig_interleaver_bit			),
		.tx_gen_sig_add_cyclic_prefix_valid (tx_gen_sig_add_cyclic_prefix_valid	),
		.tx_gen_sig_add_cyclic_prefix_re    (tx_gen_sig_add_cyclic_prefix_re	),
		.tx_gen_sig_add_cyclic_prefix_im    (tx_gen_sig_add_cyclic_prefix_im	),
		.tx_Upsample						(2'd2								),
		.tx_Rate 							(6'd54 								),
		.tx_ConvCodeRate 					(2'd2 				 				),
		.tx_Modulation 						(2'd3 								),
		.packet_cnt 						(16'h0096							),//用户帧数
		.start_cnt 							(16'h0064							),//起始计数时刻
		.cycle_cnt 							(16'h4dbc							) //周期
	);

`ifndef DATAFROMFILE
	 always @(posedge clk_200MHz) begin
	 	if (sysrst_n == 1'b0) begin		// reset
	 		cnt_samp	<=	0;
	 	 end
	 	else if ( cnt_samp == 'd9) begin
	 		cnt_samp 	<=	0;
	 	 end
	 	else begin
	 		cnt_samp 	<=	cnt_samp + 1;
	 	 end

	  end

	wire sample_in_strobe_pre;
	 assign	sample_in_strobe	=	(cnt_samp == 'd9) ? 1'b1 : 1'b0;
	 assign sample_in_strobe_pre =  (cnt_samp == 'd8) ? 1'b1 : 1'b0;
	 always @(clk_200MHz) begin
	 	if (sysrst_n == 1'b0) begin		// reset
	 		sample_in	<=	0;
	 	 end
	 	else if (sample_in_strobe_pre == 1'b1) begin
	 		sample_in 	<=	{tx_802p11_im_out,tx_802p11_re_out};
	 	 end
	 	else begin
	 		sample_in 	<=	sample_in;
	 	 end
	  end

	
	reg   [31:0]    phase_accumulator           ;
    reg             phase_acc_valid             ;
    wire  [15:0]    dds_cfoc_i, dds_cfoc_q      ;
    wire            dds_cfoc_valid              ;

    wire            cmpy_cfoc_out_valid         ;
    wire  [31:0]    cmpy_cfoc_out_i, cmpy_cfoc_out_q;

	reg     [15:0]  sample_cfoc_i               ;// data after coarse freq offset
	reg     [15:0]  sample_cfoc_q               ;
	reg             sample_cfoc_valid           ;   
    

    always @(posedge clk_200MHz ) begin
        if (sysrst_n == 1'b0) begin
            phase_accumulator <= 'd0;
        end
        else if (sample_in_strobe == 1'b1 &&  tx_802p11_out_valid == 1'b1) begin
			phase_accumulator <= phase_accumulator - 10737418;
		end
    end

    //----------------phase_acc_valid------------------
    always @(posedge clk_200MHz) begin
        if (sysrst_n == 1'b0) begin
            phase_acc_valid <= 1'b0;
        end
        else if (sample_in_strobe == 1'b1) begin
            phase_acc_valid <= 1'b1;
        end
        else  begin
            phase_acc_valid <=  1'b0;
        end
    end

    // 6 beat latency
    dds_cfoc u_dds_cfoc (
        .aclk(clk_200MHz),                                // input wire aclk
        .s_axis_phase_tvalid(phase_acc_valid),  // input wire s_axis_phase_tvalid
        .s_axis_phase_tdata({ 4'd0,phase_accumulator[31:20]}),    // input wire [15 : 0] s_axis_phase_tdata
        .m_axis_data_tvalid(dds_cfoc_valid),    // output wire m_axis_data_tvalid
        .m_axis_data_tdata({dds_cfoc_q, dds_cfoc_i})      // output wire [31 : 0] m_axis_data_tdata
    );

	reg [15:0]	tx_802p11_im_dly,tx_802p11_re_dly;


	always @(clk_200MHz) begin
		if (sysrst_n == 1'b0) begin
			{tx_802p11_im_dly,tx_802p11_re_dly} <= 'd0;
		end
		else if (sample_in_strobe) begin
			{tx_802p11_im_dly,tx_802p11_re_dly} <= sample_in;
		end
		
	end

    cmpy_cfoc u_cmpy_cfoc (
        .aclk(clk_200MHz),                              // input wire aclk
        .s_axis_a_tvalid(dds_cfoc_valid),        // input wire s_axis_a_tvalid
        .s_axis_a_tdata({dds_cfoc_q, dds_cfoc_i}),          // input wire [31 : 0] s_axis_a_tdata
        .s_axis_b_tvalid(dds_cfoc_valid),        // input wire s_axis_b_tvalid
        .s_axis_b_tdata({tx_802p11_im_dly,tx_802p11_re_dly}),          // input wire [31 : 0] s_axis_b_tdata
        .m_axis_dout_tvalid(cmpy_cfoc_out_valid),  // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata({cmpy_cfoc_out_q, cmpy_cfoc_out_i})    // output wire [63 : 0] m_axis_dout_tdata
    );

	//----------------sample_cfoc_valid------------------
    always @(posedge clk_200MHz ) begin
        if (sysrst_n == 1'b0) begin
            sample_cfoc_valid <= 1'b0;
        end
        else begin
            sample_cfoc_valid <= cmpy_cfoc_out_valid;
        end
    end

    //----------------sample_cfoc_i/q------------------
    always @(posedge clk_200MHz ) begin
        if (sysrst_n == 1'b0) begin
            sample_cfoc_i <= 'd0;
            sample_cfoc_q <= 'd0;
        end
        else  begin
            sample_cfoc_i <= {cmpy_cfoc_out_i[31],cmpy_cfoc_out_i[27:13]};
            sample_cfoc_q <= {cmpy_cfoc_out_q[31],cmpy_cfoc_out_q[27:13]};
        end
    end


`endif

	reg 		rx_start = 0;

	always @(posedge clk_200MHz) begin
		if (sysrst_n == 1'b0) begin		// reset
			rx_start	<=	0;
		 end
		else if (cnt_samp == 'd7) begin
			rx_start 	<=	1;
		 end
	 end
`ifdef DATAFROMFILE
	always @(posedge clk_200MHz) begin
		if (sysrst_n == 1'b0) begin		// reset
			cnt_samp	<=	0;
		 end
		else if (cnt_samp == 'd9) begin
			cnt_samp 	<=	0;
		 end
		else begin
			cnt_samp 	<=	cnt_samp + 1;
		 end
	 end
	assign	sample_in_strobe	=	(cnt_samp == 'd9) ? 1'b1 : 1'b0;
	always @(posedge clk_200MHz) begin
		if (sysrst_n == 1'b0) begin		// reset
			file_i1	<=	0;
			file_q1	<=	0;
			sample_i<= 	0;
			sample_q<= 	0;
			sample_in<=	0;
		 end
		else if (rx_start == 1'b1) begin
			$fscanf(board_tx_802p11_iq_fd,"%d %d", file_i1,file_q1);
            // $fscanf(board_tx_802p11_iq_fd,"%d %d", file_i1,file_q1);
            sample_i	<= file_i1<<4;
            sample_q	<= file_q1<<4;
            sample_in[15:0] <= sample_i;
            sample_in[31:16]<= sample_q;
		 end
	 end
`endif


	wire   	sts_detect_flag	;

	Rx802_11a_Top u_Rx802_11a_Top(
		.clk                   ( clk_200MHz            ),
		.rst                   ( ~sysrst_n             ),
		.enable                ( sysrst_n              ),
		.sample_in_i           ( sample_cfoc_i      	),
		.sample_in_q           ( sample_cfoc_q       	),
		.sample_in_valid       ( sample_cfoc_valid      ),
		// .sample_in_i           ( tx_802p11_re_out      	),
		// .sample_in_q           ( tx_802p11_im_out       ),
		// .sample_in_valid       ( sample_in_strobe      ),

		.sts_detect_threshold  ( 100 				   ),
		.sts_detect_flag       ( sts_detect_flag       )
	);


	// assign byte_reversed[0] = byte_out[7];
	// assign byte_reversed[1] = byte_out[6];
	// assign byte_reversed[2] = byte_out[5];
	// assign byte_reversed[3] = byte_out[4];
	// assign byte_reversed[4] = byte_out[3];
	// assign byte_reversed[5] = byte_out[2];
	// assign byte_reversed[6] = byte_out[1];
	// assign byte_reversed[7] = byte_out[0];

	// dot11 inst_dot11 (
	// 	.clock                              (clk_200MHz							),
	// 	.enable                             (sysrst_n							),
	// 	.reset                              (~sysrst_n							),
	// 	.power_thres                        (11'd0								),
	// 	.min_plateau                        (32'd100							),
	// 	.rssi_half_db                       (11'd0								),
	// 	.sample_in                          (sample_in							),
	// 	.sample_in_strobe                   (sample_in_strobe					),
	// 	.soft_decoding                      (1'b1								),
	// 	.demod_is_ongoing                   (demod_is_ongoing					),
	// 	.pkt_begin                          (pkt_begin							),
	// 	.pkt_ht                             (pkt_ht								),
	// 	.pkt_header_valid                   (pkt_header_valid					),
	// 	.pkt_header_valid_strobe            (pkt_header_valid_strobe			),
	// 	.ht_unsupport                       (ht_unsupport						),
	// 	.pkt_rate                           (pkt_rate							),
	// 	.pkt_len                            (pkt_len							),
	// 	.pkt_len_total                      (pkt_len_total						),
	// 	.byte_out_strobe                    (byte_out_strobe					),
	// 	.byte_out                           (byte_out							),
	// 	.byte_count_total                   (byte_count_total					),
	// 	.byte_count                         (byte_count							),
	// 	.fcs_out_strobe                     (fcs_out_strobe						),
	// 	.fcs_ok                             (fcs_ok								),
	// 	.state                              (state								),
	// 	.status_code                        (status_code						),
	// 	.state_changed                      (state_changed						),
	// 	.state_history                      (state_history						),
	// 	.power_trigger                      (power_trigger						),
	// 	.short_preamble_detected            (short_preamble_detected			),
	// 	.phase_offset                       (phase_offset						),
	// 	.sync_long_metric                   (sync_long_metric					),
	// 	.sync_long_metric_stb               (sync_long_metric_stb				),
	// 	.long_preamble_detected             (long_preamble_detected				),
	// 	.sync_long_out                      (sync_long_out						),
	// 	.sync_long_out_strobe               (sync_long_out_strobe				),
	// 	.phase_offset_taken                 (phase_offset_taken					),
	// 	.sync_long_state                    (sync_long_state					),
	// 	.equalizer_out                      (equalizer_out						),
	// 	.equalizer_out_strobe               (equalizer_out_strobe				),
	// 	.equalizer_state                    (equalizer_state					),
	// 	.ofdm_symbol_eq_out_pulse           (ofdm_symbol_eq_out_pulse			),
	// 	.legacy_sig_stb                     (legacy_sig_stb						),
	// 	.legacy_rate                        (legacy_rate						),
	// 	.legacy_sig_rsvd                    (legacy_sig_rsvd					),
	// 	.legacy_len                         (legacy_len							),
	// 	.legacy_sig_parity                  (legacy_sig_parity					),
	// 	.legacy_sig_parity_ok               (legacy_sig_parity_ok				),
	// 	.legacy_sig_tail                    (legacy_sig_tail					),
	// 	.ht_sig_stb                         (ht_sig_stb							),
	// 	.ht_mcs                             (ht_mcs								),
	// 	.ht_cbw                             (ht_cbw								),
	// 	.ht_len                             (ht_len								),
	// 	.ht_smoothing                       (ht_smoothing						),
	// 	.ht_not_sounding                    (ht_not_sounding					),
	// 	.ht_aggregation                     (ht_aggregation						),
	// 	.ht_stbc                            (ht_stbc							),
	// 	.ht_fec_coding                      (ht_fec_coding						),
	// 	.ht_sgi                             (ht_sgi								),
	// 	.ht_num_ext                         (ht_num_ext							),
	// 	.ht_sig_crc_ok                      (ht_sig_crc_ok						),
	// 	.demod_out                          (demod_out							),
	// 	.demod_out_strobe                   (demod_out_strobe					),
	// 	.deinterleave_erase_out             (deinterleave_erase_out				),
	// 	.deinterleave_erase_out_strobe      (deinterleave_erase_out_strobe		),
	// 	.conv_decoder_out                   (conv_decoder_out					),
	// 	.conv_decoder_out_stb               (conv_decoder_out_stb				),
	// 	.descramble_out                     (descramble_out						),
	// 	.descramble_out_strobe              (descramble_out_strobe				),
	// 	.csi                                (csi								),
	// 	.csi_valid                          (csi_valid							)
	// );


endmodule
