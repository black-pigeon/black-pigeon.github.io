// -----------------------------------------------------------------------------
// Copyright (c) 2019-2022 All rights reserved
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : accumulate_avg
// Create 	 : 2022-05-19
// Revise 	 : 2022-
// Editor 	 : Vscode, tab size (4)
// Functions : Accumulate the input data and calculate the average value
// 			   
// -----------------------------------------------------------------------------
module accumulate_avg #(
    parameter DATA_WIDTH = 32,
    parameter DELAY_DEEPTH = 16
) ( 
    input   wire                        clk                     ,   
    input   wire                        rst                     ,
    input   wire                        enable                  ,
    input   wire                        sample_in_valid         ,    
    input   wire [DATA_WIDTH-1:0]       sample_in               ,
    output  reg                         acc_avg_out_valid       ,
    output  reg  [DATA_WIDTH-1:0]       acc_avg_out
);
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
    input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
    endfunction

    //====================================================
    // parameter define
    //====================================================
    localparam EXT_WDITH = clogb2(DELAY_DEEPTH-1);

    //====================================================
    // internal signals and resgiters
    //====================================================
    reg                                 delay_ready ; // delay enough samples 
    reg [clogb2(DELAY_DEEPTH-1)-1:0]    cnt_delay   ; // delay counter
    reg                                 sample_in_valid_dly1,sample_in_valid_dly2;
    
    reg                                 delay_ready_dly1, delay_ready_dly2, delay_ready_dly3;

    wire                                wr_ram_en   ;
    reg [clogb2(DELAY_DEEPTH-1)-1:0]    wr_ram_addr ;
    wire[DATA_WIDTH-1:0]                wr_ram_data ;

    wire                                rd_ram_en   ;
    reg [clogb2(DELAY_DEEPTH-1)-1:0]    rd_ram_addr ;
    wire[DATA_WIDTH-1:0]                rd_ram_data ;
    reg                                 rd_ram_valid;

    reg [DATA_WIDTH + EXT_WDITH-1:0]    acc_window  ;
    reg                                 acc_window_valid;
    reg [DATA_WIDTH-1:0]                acc_new     ;
    wire[DATA_WIDTH-1:0]                acc_old     ;
    wire[DATA_WIDTH + EXT_WDITH-1:0]    acc_ext_new ;
    wire[DATA_WIDTH + EXT_WDITH-1:0]    acc_ext_old ;




    //----------------cnt_delay------------------
    always @(posedge clk) begin
        if (rst == 1'b1) begin
            cnt_delay <= 'd0;
        end
        else if (enable == 1'b1) begin
            if(delay_ready == 1'b0 && sample_in_valid == 1'b1 && cnt_delay == DELAY_DEEPTH -1)begin
                cnt_delay <= 'd0;
            end
            if(delay_ready == 1'b0 && sample_in_valid == 1'b1)begin
                cnt_delay <= cnt_delay + 1'b1;
            end
        end
        else begin
            cnt_delay <= 'd0;
        end
    end

    //----------------delay_ready------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            delay_ready <= 1'b0;
        end
        else if (enable == 1'b1) begin
            if (delay_ready == 1'b0 && sample_in_valid == 1'b1 && cnt_delay == DELAY_DEEPTH -1) begin
                delay_ready <= 1'b1;
            end
        end
        else begin
            delay_ready <=  1'b0;
        end
    end

    //----------------wr_ram_addr------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            wr_ram_addr <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (sample_in_valid == 1'b1 && wr_ram_addr == DELAY_DEEPTH - 1) begin
                wr_ram_addr <= 'd0;
            end
            else if (sample_in_valid == 1'b1) begin
                wr_ram_addr <= wr_ram_addr + 1'b1;
            end
        end
        else  begin
            wr_ram_addr <=  'd0;
        end
    end

    assign wr_ram_en = sample_in_valid;
    assign wr_ram_data = sample_in;

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            sample_in_valid_dly1 <= 1'b0;
            sample_in_valid_dly2 <= 1'b0;
            delay_ready_dly1 <= 1'b0;
            delay_ready_dly2 <= 1'b0;
            delay_ready_dly3 <= 1'b0;
        end
        else  begin
            sample_in_valid_dly1 <=  sample_in_valid;
            sample_in_valid_dly2 <=  sample_in_valid_dly1;
            delay_ready_dly1 <= delay_ready;
            delay_ready_dly2 <= delay_ready_dly1;
        end
    end


    simple_2port_ram#(
        .RAM_WIDTH       ( DATA_WIDTH ),
        .RAM_DEPTH       ( DELAY_DEEPTH ),
        .RAM_PERFORMANCE ( "LOW_LATENCY" ),
        .INIT_FILE       ( "" )
    )u_simple_2port_ram(
        .addra           ( wr_ram_addr     ),
        .addrb           ( rd_ram_addr     ),
        .dina            ( wr_ram_data     ),
        .clka            ( clk             ),
        .clkb            ( clk             ),
        .wea             ( wr_ram_en       ),
        .enb             ( rd_ram_en       ),
        .rstb            ( rst             ),
        .regceb          ( 1'b1            ),
        .doutb           ( rd_ram_data     )
    );


    //----------------rd_ram_addr------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rd_ram_addr <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (sample_in_valid == 1'b1 && delay_ready == 1'b1 && (rd_ram_addr == DELAY_DEEPTH - 1)) begin
                rd_ram_addr <= 'd0;
            end
            else if (sample_in_valid == 1'b1 && delay_ready == 1'b1) begin
                rd_ram_addr <= rd_ram_addr + 1'b1;
            end
        end
        else  begin
            rd_ram_addr <=  'd0;
        end
    end

    assign rd_ram_en = sample_in_valid & delay_ready;

    //----------------rd_ram_valid------------------
    always @(posedge clk) begin
        rd_ram_valid <= rd_ram_en;
    end

    //----------------acc_new/old------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            acc_new <= 'd0;
        end
        else if (enable == 1'b1) begin
            if (delay_ready == 1'b1 && sample_in_valid == 1'b1) begin
                acc_new <= sample_in;
            end
        end
        else  begin
            acc_new <=  'd0;
        end
    end

    assign acc_old = rd_ram_data;

    assign acc_ext_new = {{EXT_WDITH{acc_new[DATA_WIDTH-1]}}, acc_new};
    assign acc_ext_old = {{EXT_WDITH{acc_old[DATA_WIDTH-1]}}, acc_old};
    
    //----------------acc_window------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            acc_window <= 'd0;
        end
        else if (enable == 1'b1) begin
            if(delay_ready == 1'b0)begin
                if(sample_in_valid == 1'b1)begin
                    acc_window <= acc_window + {{EXT_WDITH{sample_in[DATA_WIDTH-1]}},sample_in};
                end
            end
            else begin
                if (rd_ram_valid == 1'b1) begin
                   acc_window <= acc_window - acc_ext_old + acc_ext_new; 
                end
            end
        end
        else  begin
            acc_window <=  'd0;
        end
    end

    //----------------acc_window_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            acc_window_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            if (delay_ready == 1'b1 ) begin
                acc_window_valid <= rd_ram_valid;
            end
        end
        else  begin
            acc_window_valid <=  1'b0;
        end
    end

    //----------------avg_out_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            acc_avg_out_valid <= 1'b0;
        end
        else if (enable == 1'b1) begin
            // latency 2 beat
            acc_avg_out_valid <= delay_ready ? acc_window_valid | (~delay_ready_dly2 & delay_ready_dly1) : sample_in_valid_dly2;
        end
        else  begin
            acc_avg_out_valid <= 1'b0;
        end
    end

    //----------------acc_avg_out------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            acc_avg_out <= 'd0;
        end
        else if (enable == 1'b1) begin
            acc_avg_out <= acc_window[DATA_WIDTH + EXT_WDITH-1: EXT_WDITH];
        end
        else  begin
            acc_avg_out <=  'd0;
        end
    end
    
endmodule