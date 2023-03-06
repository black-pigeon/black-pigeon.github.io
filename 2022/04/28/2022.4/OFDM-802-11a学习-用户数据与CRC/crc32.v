// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : crc32
// Create 	 : 2022-04-12
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : crc32 for 802.11
// CRC polynomial coefficients: x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1
//                              0x4C11DB7 (hex)
// CRC width:                   32 bits
// CRC shift direction:         left (big endian)
// Input word width:            8 bits
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module crc32 (
    input   wire            clk_User,
    input   wire            reset   ,
    input   wire            crc_en  ,
    input   wire    [7:0]   data_in ,

    output  wire            crc_data_valid  ,
    output  reg     [7:0]   crc_data
);

    reg         crc_en_dly      ;
    wire        crc_en_neg_pls  ;
    reg         crc_flag           ;
    reg         crc_flag_dly       ;
    reg         crc_en_neg_pls_dly;
    reg  [2:0]  cnt_crc         ;

    reg [31:0]  crc_in   ;
    wire [7:0]  data   ;
    reg [31:0]  crc_out;
    reg [31:0]  crc_q;

    assign data = data_in;

    //----------------crc check------------------
    always @(*) begin
        if(crc_en == 1'b1)begin
            crc_q[0] = (crc_in[24] ^ crc_in[30] ^ data[0] ^ data[6]);
            crc_q[1] = (crc_in[24] ^ crc_in[25] ^ crc_in[30] ^ crc_in[31] ^ data[0] ^ data[1] ^ data[6] ^ data[7]);
            crc_q[2] = (crc_in[24] ^ crc_in[25] ^ crc_in[26] ^ crc_in[30] ^ crc_in[31] ^ data[0] ^ data[1] ^ data[2] ^ data[6] ^ data[7]);
            crc_q[3] = (crc_in[25] ^ crc_in[26] ^ crc_in[27] ^ crc_in[31] ^ data[1] ^ data[2] ^ data[3] ^ data[7]);
            crc_q[4] = (crc_in[24] ^ crc_in[26] ^ crc_in[27] ^ crc_in[28] ^ crc_in[30] ^ data[0] ^ data[2] ^ data[3] ^ data[4] ^ data[6]);
            crc_q[5] = (crc_in[24] ^ crc_in[25] ^ crc_in[27] ^ crc_in[28] ^ crc_in[29] ^ crc_in[30] ^ crc_in[31] ^ data[0] ^ data[1] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7]);
            crc_q[6] = (crc_in[25] ^ crc_in[26] ^ crc_in[28] ^ crc_in[29] ^ crc_in[30] ^ crc_in[31] ^ data[1] ^ data[2] ^ data[4] ^ data[5] ^ data[6] ^ data[7]);
            crc_q[7] = (crc_in[24] ^ crc_in[26] ^ crc_in[27] ^ crc_in[29] ^ crc_in[31] ^ data[0] ^ data[2] ^ data[3] ^ data[5] ^ data[7]);
            crc_q[8] = (crc_in[0] ^ crc_in[24] ^ crc_in[25] ^ crc_in[27] ^ crc_in[28] ^ data[0] ^ data[1] ^ data[3] ^ data[4]);
            crc_q[9] = (crc_in[1] ^ crc_in[25] ^ crc_in[26] ^ crc_in[28] ^ crc_in[29] ^ data[1] ^ data[2] ^ data[4] ^ data[5]);
            crc_q[10] = (crc_in[2] ^ crc_in[24] ^ crc_in[26] ^ crc_in[27] ^ crc_in[29] ^ data[0] ^ data[2] ^ data[3] ^ data[5]);
            crc_q[11] = (crc_in[3] ^ crc_in[24] ^ crc_in[25] ^ crc_in[27] ^ crc_in[28] ^ data[0] ^ data[1] ^ data[3] ^ data[4]);
            crc_q[12] = (crc_in[4] ^ crc_in[24] ^ crc_in[25] ^ crc_in[26] ^ crc_in[28] ^ crc_in[29] ^ crc_in[30] ^ data[0] ^ data[1] ^ data[2] ^ data[4] ^ data[5] ^ data[6]);
            crc_q[13] = (crc_in[5] ^ crc_in[25] ^ crc_in[26] ^ crc_in[27] ^ crc_in[29] ^ crc_in[30] ^ crc_in[31] ^ data[1] ^ data[2] ^ data[3] ^ data[5] ^ data[6] ^ data[7]);
            crc_q[14] = (crc_in[6] ^ crc_in[26] ^ crc_in[27] ^ crc_in[28] ^ crc_in[30] ^ crc_in[31] ^ data[2] ^ data[3] ^ data[4] ^ data[6] ^ data[7]);
            crc_q[15] = (crc_in[7] ^ crc_in[27] ^ crc_in[28] ^ crc_in[29] ^ crc_in[31] ^ data[3] ^ data[4] ^ data[5] ^ data[7]);
            crc_q[16] = (crc_in[8] ^ crc_in[24] ^ crc_in[28] ^ crc_in[29] ^ data[0] ^ data[4] ^ data[5]);
            crc_q[17] = (crc_in[9] ^ crc_in[25] ^ crc_in[29] ^ crc_in[30] ^ data[1] ^ data[5] ^ data[6]);
            crc_q[18] = (crc_in[10] ^ crc_in[26] ^ crc_in[30] ^ crc_in[31] ^ data[2] ^ data[6] ^ data[7]);
            crc_q[19] = (crc_in[11] ^ crc_in[27] ^ crc_in[31] ^ data[3] ^ data[7]);
            crc_q[20] = (crc_in[12] ^ crc_in[28] ^ data[4]);
            crc_q[21] = (crc_in[13] ^ crc_in[29] ^ data[5]);
            crc_q[22] = (crc_in[14] ^ crc_in[24] ^ data[0]);
            crc_q[23] = (crc_in[15] ^ crc_in[24] ^ crc_in[25] ^ crc_in[30] ^ data[0] ^ data[1] ^ data[6]);
            crc_q[24] = (crc_in[16] ^ crc_in[25] ^ crc_in[26] ^ crc_in[31] ^ data[1] ^ data[2] ^ data[7]);
            crc_q[25] = (crc_in[17] ^ crc_in[26] ^ crc_in[27] ^ data[2] ^ data[3]);
            crc_q[26] = (crc_in[18] ^ crc_in[24] ^ crc_in[27] ^ crc_in[28] ^ crc_in[30] ^ data[0] ^ data[3] ^ data[4] ^ data[6]);
            crc_q[27] = (crc_in[19] ^ crc_in[25] ^ crc_in[28] ^ crc_in[29] ^ crc_in[31] ^ data[1] ^ data[4] ^ data[5] ^ data[7]);
            crc_q[28] = (crc_in[20] ^ crc_in[26] ^ crc_in[29] ^ crc_in[30] ^ data[2] ^ data[5] ^ data[6]);
            crc_q[29] = (crc_in[21] ^ crc_in[27] ^ crc_in[30] ^ crc_in[31] ^ data[3] ^ data[6] ^ data[7]);
            crc_q[30] = (crc_in[22] ^ crc_in[28] ^ crc_in[31] ^ data[4] ^ data[7]);
            crc_q[31] = (crc_in[23] ^ crc_in[29] ^ data[5]);
        end
        else begin
            crc_q = 32'hFFFF_FFFF;
        end
    end


    always@(posedge clk_User)begin
        crc_en_dly <= crc_en;
    end

    assign crc_en_neg_pls = (~crc_en) & crc_en_dly;

    always@(posedge clk_User)begin
        if(reset == 1'b1)begin
            crc_in <= 32'hFFFF_FFFF;
            crc_out <= 32'hFFFF_FFFF;
        end
        else if(cnt_crc=='d3 && crc_flag == 1'b1)begin
            crc_in <= 32'hFFFF_FFFF;
            crc_out <= 32'hFFFF_FFFF;
        end
        else if(crc_en)begin
            crc_in <= crc_q;
            crc_out <= crc_q ^ 32'hFFFF_FFFF;
        end
    end

    //----------------crc_flag------------------
    always @(posedge clk_User) begin
        if(reset == 1'b1)begin
            crc_flag <= 1'b0;
        end
        else if(cnt_crc=='d3 && crc_flag == 1'b1) begin
            crc_flag <= 1'b0;
        end
        else if(crc_en_neg_pls)begin
            crc_flag <= 1'b1;
        end
    end

    always @(posedge clk_User) begin
        crc_flag_dly <= crc_flag;
        crc_en_neg_pls_dly <= crc_en_neg_pls;
    end

    //----------------cnt_crc------------------
    always @(posedge clk_User) begin
        if(reset == 1'b1)begin
            cnt_crc <= 'd0;
        end
        else if(cnt_crc=='d3 && crc_flag == 1'b1)begin
            cnt_crc <= 'd0;
        end
        else if(crc_flag == 1'b1 || crc_en_neg_pls)begin
            cnt_crc <= cnt_crc + 1'b1;
        end
    end

    //----------------crc_data------------------
    always @(posedge clk_User) begin
        if(reset == 1'b1)begin
            crc_data <= 'd0;
        end
        else if(crc_en == 1'b1) begin
            crc_data <= data_in;
        end
        else if(crc_en_neg_pls | crc_flag) begin
            case(cnt_crc)
                0: crc_data <= crc_out[31:24];
                1: crc_data <= crc_out[23:16];
                2: crc_data <= crc_out[15:8];
                3: crc_data <= crc_out[7:0];
                default: crc_data <= 'd0;
            endcase
        end
        else begin
            crc_data <= 'd0;
        end
    end

    assign crc_data_valid = crc_en_dly | crc_en_neg_pls_dly | crc_flag_dly;
    
endmodule