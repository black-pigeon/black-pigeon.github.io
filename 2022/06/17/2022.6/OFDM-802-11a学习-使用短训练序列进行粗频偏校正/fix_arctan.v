// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : fix_actan
// Create 	 : 2022-05-27
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : fix point arctan function implementation in verilog
//             Atan(x)=M_PI_4*x - x*(fabs(x) - 1)*(0.2447 + 0.0663*fabs(x))
// 			   
// -----------------------------------------------------------------------------
module fix_arctan (
    input   wire            clk                         ,
    input   wire            rst                         ,
    input   wire            enable                      ,
    input   wire    [31:0]  y_in                        , // input q 
    input   wire    [31:0]  x_in                        , // input I
    input   wire            xy_in_valid                 ,
    output  reg     [31:0]  angle_out                   , // angle out of current 
    output  reg             angle_out_valid             ,
    output  reg     [31:0]  angle_out_div16x2pi         , // fix point angle out 
    output  reg             angle_out_div16x2pi_valid
);

    //====================================================
    // parameter define
    //====================================================
    localparam IDLE     = 3'd0;
    localparam DIV      = 3'd1;
    localparam XABS     = 3'd2;
    localparam ABS663   = 3'd3;
    localparam XMABS    = 3'd4;
    localparam XMABS2   = 3'd5;
    localparam M_PI_4   = 3'd6;
    localparam MULT_LAST= 3'd7;

    localparam FIX_ONE      = 32'd268435456;
    localparam FIX_QUART_PI = 32'd210828714;
    localparam FIX_P2447    = 32'd65686156;
    localparam FIX_P0663    = 32'd17797270;
    localparam FIX_DIV2PIX16= 32'd2670176;


    //====================================================
    // internalsignals and registers
    //====================================================
    reg  [2:0]      state               ;
    reg             xy_in_valid_r       ;
    reg  [31:0]     x_in_r              ;
    reg  [31:0]     y_in_r              ;
    wire            div_out_valid       ;
    wire [63:0]     div_out             ;
    reg  [31:0]     fix_div_out         ; // 1 bit sign, 3 bit quotient, 28 bit fractional
    reg             fix_div_out_valid   ;
    reg  [31:0]     abs_div             ;
    reg  [31:0]     abs_div_minus_1     ;
    reg             abs_div_valid       ;
    reg  [31:0]     mult_in_a           ;
    reg  [31:0]     mult_in_b           ;
    reg             mult_in_valid       ;
    wire [63:0]     mult_out            ;
    reg  [2:0]      mult_in_valid_dly   ;
    wire            mult_out_valid      ;
    reg             abs663_valid        ;
    reg  [31:0]     abs663_plus_p2447   ;
    reg             xmabs_valid         ;
    reg  [31:0]     xmabs_data          ;
    reg             xmabs2_valid        ;
    reg  [31:0]     xmabs2_data         ;
    reg             xmquart_pi_valid    ;
    reg  [31:0]     xmquart_pi_data     ;


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            x_in_r <= 'd0;
            y_in_r <= 'd0;
        end
        else if(xy_in_valid == 1'b1)begin
            x_in_r <= (x_in==0)? 1: x_in;
            y_in_r <= y_in;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            xy_in_valid_r <= 1'b0;
        end
        else  begin
            xy_in_valid_r <= xy_in_valid;
        end

    end


      
    //----------------state------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE : begin
                    if(enable == 1'b1 && xy_in_valid == 1'b1)begin
                        state <= DIV;
                    end
                end

                DIV : begin
                    if(fix_div_out_valid == 1'b1)begin
                        state <= XABS;
                    end
                end

                XABS : begin
                    if(abs_div_valid == 1'b1)begin
                        state <= ABS663;
                    end
                end

                ABS663 : begin
                    if (abs663_valid == 1'b1) begin
                        state <= XMABS;
                    end
                end

                XMABS : begin
                    if (xmabs_valid == 1'b1) begin
                        state <= XMABS2;
                    end
                end

                XMABS2 : begin
                    if (xmabs2_valid == 1'b1) begin
                        state <= M_PI_4;
                    end
                end

                M_PI_4 : begin
                    if (xmquart_pi_valid == 1'b1) begin
                        state <= MULT_LAST;
                    end
                end

                MULT_LAST: begin
                    if(angle_out_div16x2pi_valid)begin
                        state <= IDLE;
                    end
                end

                default : state <= IDLE;
            endcase
        end
    end

    div_gen_tb u_div_gen_tb (
        .aclk(clk),                             // input wire aclk
        .s_axis_divisor_tvalid(xy_in_valid_r),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(x_in_r),            // input wire [31 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(xy_in_valid_r),   // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(y_in_r),           // input wire [31 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(div_out_valid),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(div_out)            // output wire [47 : 0] m_axis_dout_tdata
    );

    //----------------fix_div_out------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            fix_div_out <= 'd0;
        end
        else if (enable == 1'b1) begin
            // 1 bit sign, 3 bit quotient, 28 bit fractional
            fix_div_out <= {div_out[63], div_out[34:32], 28'd0} + {{4{div_out[31]}},div_out[30:3]};
        end
    end

    //----------------fix_div_out_valid------------------
    always @(posedge clk ) begin
        fix_div_out_valid <= div_out_valid;
        abs_div_valid <= fix_div_out_valid;
    end

    //----------------abs_div------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            abs_div <= 'd0;
            abs_div_minus_1 <= 'd0;
        end
        else if (fix_div_out_valid == 1'b1) begin
            abs_div <= fix_div_out[31] ? (~fix_div_out)+1: fix_div_out ;
            abs_div_minus_1 <= fix_div_out[31] ? (~fix_div_out)+1 - FIX_ONE: fix_div_out - FIX_ONE;
        end
    end


    //----------------mult_in_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            mult_in_valid <= 1'b0;
            mult_in_a <= 'd0;
            mult_in_b <= 'd0;
        end
        else if (state == XABS &&  abs_div_valid == 1'b1) begin
            mult_in_valid <= 1'b1;
            mult_in_a <= abs_div;
            mult_in_b <= FIX_P0663;
        end
        else if (state == ABS663 && abs663_valid == 1'b1) begin
            mult_in_valid <= 1'b1;
            mult_in_a <= abs_div_minus_1;
            mult_in_b <= fix_div_out;
        end
        else if (state == XMABS && xmabs_valid == 1'b1) begin
            mult_in_valid <= 1'b1;
            mult_in_a <= xmabs_data;
            mult_in_b <= abs663_plus_p2447;
        end
        else if (state == XMABS2 && xmabs2_valid == 1'b1) begin
            mult_in_valid <= 1'b1;
            mult_in_a <= fix_div_out;
            mult_in_b <= FIX_QUART_PI;
        end
        else if (state == MULT_LAST && angle_out_valid == 1'b1) begin
            mult_in_valid <= 1'b1;
            mult_in_a <= FIX_DIV2PIX16;
            mult_in_b <= angle_out;
        end
        else  begin
            mult_in_valid <=  1'b0;
        end
    end

    always @(posedge clk) begin
        mult_in_valid_dly <= {mult_in_valid_dly[1:0], mult_in_valid};
    end

    assign mult_out_valid = mult_in_valid_dly[2];

    mult_fix_arctan u_mult_fix_arctan (
        .CLK(clk),  // input wire CLK
        .A(mult_in_a),      // input wire [31 : 0] A
        .B(mult_in_b),      // input wire [31 : 0] B
        .P(mult_out)      // output wire [63 : 0] P
    );

    //----------------abs663_plus_p2447------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            abs663_plus_p2447 <= 'd0;
            abs663_valid <= 1'b0;
            xmabs_data <= 'd0;
            xmabs_valid <= 1'b0;
            xmabs2_data <= 'd0;
            xmabs2_valid <= 1'b0;
            xmquart_pi_data <= 'd0;
            xmquart_pi_valid <= 1'b0;
            angle_out_div16x2pi <= 'd0;
            angle_out_div16x2pi_valid <= 1'b0;
        end
        else if (state == ABS663 && mult_out_valid == 1'b1) begin
            abs663_plus_p2447 <= {mult_out[63], mult_out[58:56], mult_out[55:28]} + FIX_P2447;
            abs663_valid <= 1'b1;
        end
        else if (state == XMABS && mult_out_valid == 1'b1) begin
            xmabs_data <= {mult_out[63], mult_out[58:56], mult_out[55:28]};
            xmabs_valid <= 1'b1;
        end
        else if (state == XMABS2 && mult_out_valid == 1'b1) begin
            xmabs2_data <= {mult_out[63], mult_out[58:56], mult_out[55:28]};
            xmabs2_valid <= 1'b1;
        end
        else if (state == M_PI_4 && mult_out_valid == 1'b1) begin
            xmquart_pi_data <= {mult_out[63], mult_out[58:56], mult_out[55:28]};
            xmquart_pi_valid <= 1'b1;
        end
        else if (state == MULT_LAST && mult_out_valid == 1'b1) begin
            angle_out_div16x2pi <= {mult_out[63], mult_out[58:56], mult_out[55:28]};
            angle_out_div16x2pi_valid <= 1'b1;
        end
        else begin
            abs663_valid <= 1'b0;
            xmabs_valid <= 1'b0;
            xmabs2_valid <= 1'b0;
            xmquart_pi_valid <= 1'b0;
            angle_out_div16x2pi_valid <= 1'b0;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            angle_out <= 'd0;
            angle_out_valid <= 1'b0;
        end
        else if (xmquart_pi_valid ==1'b1 ) begin
            angle_out <= xmquart_pi_data - xmabs2_data;
            angle_out_valid <= 1'b1;
        end
        else begin
            angle_out_valid <= 1'b0;
        end
    end

endmodule