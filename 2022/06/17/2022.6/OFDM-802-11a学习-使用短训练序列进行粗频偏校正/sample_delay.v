module sample_delay #(
    parameter DATA_WIDTH = 32,
    parameter DELAY_DEEPTH = 16
) ( 
    input   wire                        clk                     ,   
    input   wire                        rst                     ,
    input   wire                        enable                  ,
    input   wire                        sample_in_valid         ,    
    input   wire [DATA_WIDTH-1:0]       sample_in               ,
    output  reg                         sample_delay_out_valid  ,
    output  wire [DATA_WIDTH-1:0]       sample_delay_out
);
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
    input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
        depth = depth >> 1;
    endfunction

    //====================================================
    // internal signals and resgiters
    //====================================================
    reg                                 delay_ready ; // delay enough samples 
    reg [clogb2(DELAY_DEEPTH-1)-1:0]    cnt_delay   ; // delay counter

    wire                                wr_ram_en   ;
    reg [clogb2(DELAY_DEEPTH-1)-1:0]    wr_ram_addr ;
    wire[DATA_WIDTH-1:0]                wr_ram_data ;

    wire                                rd_ram_en   ;
    reg [clogb2(DELAY_DEEPTH-1)-1:0]    rd_ram_addr ;
    wire[DATA_WIDTH-1:0]                rd_ram_data ;


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

    //----------------sample_delay_out_valid------------------
    always @(posedge clk) begin
        sample_delay_out_valid <= rd_ram_en;
    end

    assign sample_delay_out = rd_ram_data;
    
endmodule