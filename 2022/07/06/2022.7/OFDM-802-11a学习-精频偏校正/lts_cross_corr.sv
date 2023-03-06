// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : lts_cross_corr
// Create 	 : 2022-06-06
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : long training sequence detect
// 			   
// -----------------------------------------------------------------------------
module long_training_seq_cross_corr (
    input   wire            clk                 ,
    input   wire            rst                 ,
    input   wire            enable              ,
    input   wire            sample_in_valid     ,
    input   wire    [15:0]  sample_in_i         ,
    input   wire    [15:0]  sample_in_q         ,
    output  reg     [31:0]  lts_cross_corr      ,
    output  reg             lts_cross_corr_valid
);

parameter [15:0] LTS_I [0:63]= {
    64896,  50,     376,    65160,  65525,  308,    65014,  65037, 
    65392,  65305,  65289,  285,    337,    64998,  65302,  151, 
    256,    488,    65444,  240,    100,    64976,  4,      218, 
    400,    65379,  65064,  245,    86,     397,    163,    65515,  
    640,    65515,  163,    397,    86,     245,    65064,  65379,  
    400,    218,    4,      64976,  100,    240,    65444,  488, 
    256,    151,    65302,  64998,  337,    285,    65289,  65305, 
    65392,  65037,  65014,  308,    65525,  65160,  376,    50};

parameter [15:0] LTS_Q [0:63]={
    0,      65136,  65102,  65064,  65316,  303,    84,     68, 
    618,    89,     65203,  65478,  65158,  65269,  65375,  65133, 
    256,    17,     64878,  61,     240,    194,    471,    65519, 
    106,    435,    226,    359,    65422,  65197,  455,    493, 
    0,      65043,  65081,  339,    114,    65177,  65310,  65101, 
    65430,  17,     65065,  65342,  65296,  65475,  658,    65519, 
    65280,  403,    161,    267,    378,    58,     333,    65447, 
    64918,  65468,  65452,  65233,  220,    472,    434,    400};


    reg [63:0]  sign_i          ;
    reg [63:0]  sign_q          ;
    reg         sign_valid      ;

    reg [15:0]  mult_i [0:63]   ;
    reg [15:0]  mult_q [0:63]   ;
    reg         mult_valid      ;

    reg [15:0]  sum_stage1_i [0:15] ;
    reg [15:0]  sum_stage1_q [0:15] ;
    reg         sum_stage1_valid    ;

    reg [15:0]  sum_stage2_i [0:3]  ;
    reg [15:0]  sum_stage2_q [0:3]  ;
    reg         sum_stage2_valid    ;

    reg [15:0]  sum_stage3_i        ;
    reg [15:0]  sum_stage3_q        ;
    reg         sum_stage3_valid    ;

    wire [15:0] abs_i               ;
    wire [15:0] abs_q               ;



    


    //----------------sign_i/q------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sign_i <= 'd0;
            sign_q <= 'd0;
        end
        else if (enable == 1'b1 ) begin
            if (sample_in_valid == 1'b1) begin
                sign_i <= {sample_in_i[15], sign_i[63:1]};
                sign_q <= {sample_in_q[15], sign_q[63:1]};
            end
        end
        else begin
            sign_i <= 'd0;
            sign_q <= 'd0;
        end
    end

    //----------------sign_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sign_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            sign_valid <= sample_in_valid;
        end
        else  begin
            sign_valid <=  1'b0;;
        end
    end

    //----------------mult_i/q------------------
    // s(i:i+63).*cnoj(LTS)
    // s[i]=a+ib, LT[i]=c-id
    // s[i]*LT[i] = (ac+bd) + i(bc -ad), a b could be the sign bit 
    genvar i;
    generate;
        for ( i=0; i<64; i=i+1) begin
            always @(posedge clk ) begin
                if (rst==1'b1) begin
                    mult_i[i] <= 'd0;
                    mult_q[i] <= 'd0;
                end
                else if (enable == 1'b1) begin
                    if (sign_valid == 1'b1) begin
                        case({sign_i[i],sign_q[i]})
                            2'b00: begin 
                                //a=1,b=1, s[i]*LT[i] = (c+d) + i(c-d)
                                mult_i[i] <= LTS_I[i] + LTS_Q[i];
                                mult_q[i] <= LTS_I[i] - LTS_Q[i];
                            end

                            2'b01: begin
                                //a=1,b=-1, s[i]*LT[i] = (c-d) + i(-c-d)
                                mult_i[i] <= LTS_I[i] - LTS_Q[i];
                                mult_q[i] <= ((~LTS_I[i]) + 1) - LTS_Q[i];
                            end
                            
                            2'b10: begin
                                //a=-1,b=1, s[i]*LT[i] = (-c+d) + i(c-d)
                                mult_i[i] <= LTS_Q[i] - LTS_I[i];
                                mult_q[i] <= LTS_I[i] + LTS_Q[i];
                            end

                            2'b11: begin
                                //a=-1,b=-1, s[i]*LT[i] = (-c-d) + i(-c+d)
                                mult_i[i] <= ((~LTS_I[i]) + 1) - LTS_Q[i];
                                mult_q[i] <= LTS_Q[i] - LTS_I[i] ;
                            end
                        endcase
                    end
                end
                else begin
                    mult_i[i] <=  'd0;
                    mult_q[i] <= 'd0;
                end
            end
        end
    endgenerate

    //----------------mult_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            mult_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            mult_valid <= sign_valid;
        end
        else  begin
            mult_valid <=  1'b0;;
        end
    end

    //----------------sum_stage1_i/q------------------
    generate
        for (i=0; i<16; i=i+1) begin
            always @(posedge clk ) begin
                if (rst==1'b1) begin
                    sum_stage1_i[i] <= 'd0;
                    sum_stage1_q[i] <= 'd0;
                end
                else if (enable == 1'b1) begin
                    if (mult_valid == 1'b1) begin
                        sum_stage1_i[i] <= mult_i[4*i] + mult_i[4*i+1] + mult_i[4*i+2] + mult_i[4*i+3];
                        sum_stage1_q[i] <= mult_q[4*i] + mult_q[4*i+1] + mult_q[4*i+2] + mult_q[4*i+3]; 
                    end
                end
                else  begin
                    sum_stage1_i[i] <= 'd0;
                    sum_stage1_q[i] <= 'd0;
                end
            end  
        end
    endgenerate

    //----------------sum_stage1_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sum_stage1_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            sum_stage1_valid <= mult_valid;
        end
        else  begin
            sum_stage1_valid <=  1'b0;;
        end
    end


    //----------------sum_stage2_i/q------------------
    generate
        for (i=0; i<4; i=i+1) begin
            always @(posedge clk ) begin
                if (rst==1'b1) begin
                    sum_stage2_i[i] <= 'd0;
                    sum_stage2_q[i] <= 'd0;
                end
                else if (enable == 1'b1 ) begin
                    if (sum_stage1_valid == 1'b1) begin
                        sum_stage2_i[i] <= sum_stage1_i[4*i] + sum_stage1_i[4*i+1] + sum_stage1_i[4*i+2] + sum_stage1_i[4*i+3];
                        sum_stage2_q[i] <= sum_stage1_q[4*i] + sum_stage1_q[4*i+1] + sum_stage1_q[4*i+2] + sum_stage1_q[4*i+3];
                    end
                end
                else  begin
                    sum_stage2_i[i] <= 'd0;
                    sum_stage2_q[i] <= 'd0;
                end
            end  
        end
    endgenerate

    //----------------sum_stage2_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sum_stage2_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            sum_stage2_valid <= sum_stage1_valid;
        end
        else  begin
            sum_stage2_valid <=  1'b0;;
        end
    end


    //----------------sum_stage3_i/q------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sum_stage3_i <= 'd0;
            sum_stage3_q <= 'd0;
        end
        else if (enable == 1'b1 ) begin
            if (sum_stage2_valid == 1'b1) begin
                sum_stage3_i <= sum_stage2_i[0] + sum_stage2_i[1] + sum_stage2_i[2] + sum_stage2_i[3];
                sum_stage3_q <= sum_stage2_q[0] + sum_stage2_q[1] + sum_stage2_q[2] + sum_stage2_q[3];
            end
        end
        else  begin
            sum_stage3_i <= 'd0;
            sum_stage3_q <= 'd0;
        end
    end  


    //----------------sum_stage3_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sum_stage3_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            sum_stage3_valid <= sum_stage2_valid;
        end
        else  begin
            sum_stage3_valid <=  1'b0;;
        end
    end


    // //----------------abs_i/q------------------
    // always @(posedge clk ) begin
    //     if (rst==1'b1) begin
    //         abs_i <= 'd0;
    //         abs_q <= 'd0;
    //     end
    //     else if (enable == 1'b1 ) begin
    //         if (sum_stage3_valid == 1'b1) begin
    //             abs_i <= sum_stage3_i[15] ? (~sum_stage3_i + 1) : sum_stage3_i;
    //             abs_q <= sum_stage3_q[15] ? (~sum_stage3_q + 1) : sum_stage3_q;
    //         end
    //     end
    //     else  begin
    //         abs_i <= 'd0;
    //         abs_q <= 'd0;
    //     end
    // end  


    // //----------------abs_valid------------------
    // always @(posedge clk ) begin
    //     if (rst==1'b1) begin
    //         abs_valid <= 1'b0;
    //     end
    //     else if (enable == 1'b1) begin
    //         abs_valid <= sum_stage3_valid;
    //     end
    //     else  begin
    //         abs_valid <=  1'b0;;
    //     end
    // end

    assign abs_i = sum_stage3_i[15] ? (~sum_stage3_i + 1) : sum_stage3_i;
    assign abs_q = sum_stage3_q[15] ? (~sum_stage3_q + 1) : sum_stage3_q;

    //-----------------lts_cross_corr-----------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            lts_cross_corr <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (sum_stage3_valid == 1'b1) begin
                if (abs_i >= abs_q) begin
                    lts_cross_corr <= abs_i + abs_q[15:2];
                end
                else begin
                    lts_cross_corr <= abs_i[15:2] + abs_q;
                end
            end
        end
        else  begin
            lts_cross_corr <= 'd0;
        end
    end  

    //----------------lts_cross_corr_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            lts_cross_corr_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            lts_cross_corr_valid <= sum_stage3_valid;
        end
        else  begin
            lts_cross_corr_valid <=  1'b0;;
        end
    end

endmodule