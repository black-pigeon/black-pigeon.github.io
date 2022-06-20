`timescale 1ns / 1ps


module tb_lts_detect();

    parameter PERIOD  = 10; 

    parameter [15:0] LTS_I [0:63]= {
        65216,  25,     188,    65348,  65530,  154,    65275,  65286, 
        65464,  65420,  65412,  142,    168,    65267,  65419,  76, 
        128,    244,    65490,  120,    50,     65256,  2,      109,
        200,    65458,  65300,  123,    43,     198,    81,     65526, 
        320,    65526,  81,     198,    43,     123,    65300,  65458,
        200,    109,    2,      65256,  50,     120,    65490,  244,
        128,    76,     65419,  65267,  168,    142,    65412,  65420,
        65464,  65286,  65275,  154,    65530,  65348,  188,    25 
    };

    parameter [15:0] LTS_Q [0:63]={
        0,      65336,  65319,  65300,  65426,  152,    42,     34,
        309,    45,     65370,  65507,  65347,  65402,  65456,  65335,
        128,    8,      65207,  31,     120,    97,     236,    65528,
        53,     217,    113,    180,    65479,  65366,  228,    246,
        0,      65290,  65308,  170,    57,     65356,  65423,  65319,
        65483,  8,      65300,  65439,  65416,  65505,  329,    65528,
        65408,  201,    80,     134,    189,    29,     166,    65491,
        65227,  65502,  65494,  65384,  110,    236,    217,    200
    };


    // fix_arctan Inputs
    reg   clk                                  ;
    reg   rst                                  ;
    reg   enable                               ;
    reg   [15:0]    sample_in_q                ;
    reg   [15:0]    sample_in_i                ;
    reg             sample_in_valid            ;

    // fix_arctan Outputs
    wire  [31:0]  lts_cross_corr                    ;
    wire  lts_cross_corr_valid                      ;
    reg [5:0] index;


    initial begin
        clk = 0;
        forever #(PERIOD/2)  clk=~clk;
    end

    initial begin
        rst = 1;
        enable = 0;
        sample_in_i = 0;
        sample_in_q = 0;
        sample_in_valid = 0;
        #(PERIOD*20) rst  =  0;
        repeat(20)@(posedge clk);
        enable = 1;
        sample_in_valid = 1;
    end

    always @(posedge clk) begin
        if(rst == 1'b1)begin
            index <= 'd0;
        end
        else if (enable == 1'b1 && index == 63 && sample_in_valid == 1'b1) begin
            index <= 'd0;
        end
        else if (enable == 1'b1 && sample_in_valid == 1'b1) begin
            index <= index + 1'b1;
        end
    end

    always @(posedge clk) begin
        if(rst == 1'b1)begin
            sample_in_i <= 'd0;
            sample_in_q <= 'd0;
        end
        else if(enable == 1'b1 && sample_in_valid == 1'b1)begin
            sample_in_i <= LTS_I[index];
            sample_in_q <= LTS_Q[index];
        end
        else begin
            sample_in_i <= 'd0;
            sample_in_q <= 'd0;
        end
    end

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

endmodule
