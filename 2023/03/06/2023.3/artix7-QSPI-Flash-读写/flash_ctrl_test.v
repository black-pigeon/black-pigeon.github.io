// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : flash_ctrl_test
// Create 	 : 2023-03-03
// Revise 	 : 2023-
// Editor 	 : Vscode, tab size (4)
// Version	 : v1.0  
// Functions : 
// License	  : License: LGPL-3.0-or-later
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
module flash_ctrl_test(
    input   wire            clk         ,
    input   wire            rst_n       ,
    output  wire            status_led  ,
    output  wire            spi_cs_n    ,
    output  wire            spi_mosi    ,
    input   wire            spi_miso    
);
    //====================================================
    //parameter define
    //====================================================
    parameter CMD_TYPE_RDID    = 4'd1;
    parameter CMD_TYPE_RDJDID  = 4'd2;
    parameter CMD_TYPE_WR_DATA = 4'd3;
    parameter CMD_TYPE_ERASE   = 4'd4;
    parameter CMD_TYPE_RD_DATA = 4'd5;


    localparam IDLE         = 3'd0;
    localparam ARBIT        = 3'd1;
    localparam ERASE        = 3'd2;
    localparam READ_ID      = 3'd3;
    localparam READ_JDID    = 3'd4;
    localparam READ_DATA    = 3'd5;
    localparam WRITE        = 3'd6;

    localparam FLASH_REGION = 24'h20000;




    //====================================================
    // internal signals and registers
    //====================================================
    reg     [2:0]   state   ;

    wire            cmd_trigger     ;
    wire    [3:0]   cmd_type        ;
    wire    [31:0]  total_bytes_to_pp;
    wire    [31:0]  total_bytes_to_rd;
    wire    [31:0]  total_bytes_to_erase;


    reg     [1:0]   cmd_trigger_dly ;
    reg     [23:0]  rx_data_shift   ;
    reg     [7:0]   device_id       ;
    reg     [23:0]  device_jdid     ;
    wire            wr_flash_done   ;
    wire            rd_flash_done   ;
    wire            erase_flash_done;


    reg             cmd_req         ;
    wire            cmd_ack         ;

    wire    [7:0]   wr_data         ;
    wire            wr_data_pop     ;
    reg     [31:0]  cnt_wr_data     ;
    reg     [31:0]  cnt_rd_data     ;
    wire    [7:0]   rd_data         ;
    wire            rd_data_valid   ;
    wire            flash_is_busy   ;
    wire            rst             ;
    reg             flash_is_erased ;
    reg             error_flag      ;

    assign rst = ~rst_n;


    STARTUPE2 #( 
        .PROG_USR           ("FALSE"         ),//Activate program event security feature. Requires encrypted bitstreams.
        .SIM_CCLK_FREQ      (0.0             ) //Set the Configuration Clock Frequency(ns) for simulation
    )
    STARTUPE2_inst(     
        .CFGCLK             (                ),//1-bit output: Configuration main clock output
        .CFGMCLK            (                ),//1-bit output: Configuration internal oscillator clock output
        .EOS                (                ),//1-bit output: Active high output signal indicating the End Of Startup.
        .PREQ               (                ),//1-bit output: PROGRAM request to fabric output
        .CLK                (0               ),//1-bit input: User start-up clock input
        .GSR                (0               ),//1-bit input: Global Set/Reset input(GSR cannot be used for the port name)
        .GTS                (0               ),//1-bit input: Global 3-state input(GTS cannot be used for the port name)
        .KEYCLEARB          (1               ),//1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM(BBRAM)
        .PACK               (1               ),//1-bit input: PROGRAM acknowledge input
        .USRCCLKO           (spi_clk         ),//1-bit input: User CCLK input
        .USRCCLKTS          (0               ),//1-bit input: User CCLK 3-state enable input
        .USRDONEO           (1               ),//1-bit input: User DONE pin output control
        .USRDONETS          (1               ) //1-bit input: User DONE 3-state enable output
    );


    flash_ctrl  flash_ctrl_dut (
        .clk (clk ),
        .rst (rst ),
        .cmd_type (cmd_type ),
        .cmd_req (cmd_req ),
        .cmd_ack (cmd_ack ),
        .total_bytes_to_pp (FLASH_REGION ),
        .wr_data (wr_data ),
        .wr_data_pop (wr_data_pop ),
        .wr_flash_done (wr_flash_done),
        .total_bytes_to_erase(FLASH_REGION),
        .erase_flash_done(erase_flash_done),
        .total_bytes_to_rd (FLASH_REGION ),
        .rd_data (rd_data ),
        .rd_data_valid (rd_data_valid ),
        .rd_flash_done (rd_flash_done ),
        .flash_is_busy (flash_is_busy ),
        .spi_clk (spi_clk ),
        .spi_cs_n (spi_cs_n ),
        .spi_mosi (spi_mosi ),
        .spi_miso (spi_miso )
    );


    vio_0 u_vio_0 (
        .clk(clk),                // input wire clk
        .probe_in0(device_id),    // input wire [7 : 0] probe_in0
        .probe_in1(device_jdid),    // input wire [23 : 0] probe_in1
        .probe_in2(error_flag),    // input wire [0 : 0] probe_in2
        .probe_out0(cmd_trigger),  // output wire [0 : 0] probe_out0
        .probe_out1(cmd_type)  // output wire [3 : 0] probe_out1
    );

    //----------------cmd_trigger_dly------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cmd_trigger_dly <= 'd0;
        end else begin
            cmd_trigger_dly <=  {cmd_trigger_dly[0], cmd_trigger};
        end
    end

    //----------------cmd_req ------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cmd_req <= 1'b0;
        end else if (state == IDLE && cmd_trigger_dly == 2'b01) begin
            cmd_req <= 1'b1;
        end else if (state == ARBIT && cmd_ack == 1'b1) begin
            cmd_req <= 1'b0;
        end
    end


    //----------------state------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state  <= IDLE ;
        end else begin
            case (state)
                IDLE : begin
                    if (cmd_trigger_dly == 2'b01) begin
                        state <= ARBIT;
                    end
                end

                ARBIT : begin
                    if(flash_is_busy == 1'b0 && cmd_req == 1'b1 && cmd_ack == 1'b1)begin
                        case (cmd_type)
                            CMD_TYPE_RDID : state <= READ_ID;
                            CMD_TYPE_RDJDID : state <= READ_JDID;
                            CMD_TYPE_RD_DATA : state <= READ_DATA;
                            CMD_TYPE_ERASE : state <= ERASE;
                            CMD_TYPE_WR_DATA : state <= WRITE;

                            default : state <= ARBIT;
                        endcase
                    end
                end

                READ_ID : begin
                    if (rd_flash_done) begin
                        state <= IDLE;
                    end
                end

                READ_JDID : begin
                    if(rd_flash_done)begin
                        state <= IDLE;
                    end
                end

                READ_DATA : begin
                    if (rd_flash_done) begin
                        state <= IDLE;
                    end
                end

                ERASE : begin
                    if (erase_flash_done) begin
                        state <= IDLE;
                    end
                end


                WRITE : begin
                    if (wr_flash_done) begin
                        state <= IDLE;
                    end
                end

                default : begin
                    state <= IDLE;
                end
            endcase
        end 
    end

    //----------------wr_data------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_wr_data <= 'd0;
        end else if (state == WRITE) begin
            if (wr_data_pop) begin
                cnt_wr_data <= cnt_wr_data + 1'b1;
            end
        end else begin
            cnt_wr_data <=  'd0;
        end
    end

    assign wr_data = cnt_wr_data[7:0];

    //----------------cnt_rd_data------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_rd_data <= 'd0;
        end else if (state == READ_DATA) begin
            if (rd_data_valid) begin
                cnt_rd_data <= cnt_rd_data + 1'b1;
            end
        end else begin
            cnt_rd_data <=  'd0;
        end
    end

    //----------------rx_data_shift------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rx_data_shift <= 'd0;
        end else if (rd_data_valid == 1'b1 && (state == READ_ID || state == READ_JDID)) begin
            rx_data_shift <= {rx_data_shift[15:0], rd_data};
        end
    end

    //----------------device_id------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            device_id <= 'd0;
        end else if (state == READ_ID && rd_flash_done) begin
            device_id <= rx_data_shift[7:0];
        end 
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            device_jdid <= 'd0;
        end else if (state == READ_JDID && rd_flash_done) begin
            device_jdid <= rx_data_shift;
        end 
    end

    //----------------flash_is_erased------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            flash_is_erased <= 1'b0;
        end else if (cmd_trigger_dly==2'b01 && cmd_type == CMD_TYPE_ERASE) begin
            flash_is_erased <= 1'b1;
        end else if((cmd_trigger_dly==2'b01 && cmd_type == CMD_TYPE_WR_DATA))begin
            flash_is_erased <=  1'b0;
        end
    end

    //----------------if------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            error_flag <= 1'b0;
        end else if (state == READ_DATA && flash_is_erased == 1'b1 && rd_data != 8'hFF && rd_data_valid == 1'b1) begin
            error_flag <= 1'b1;
        end else if(state == READ_DATA && flash_is_erased == 1'b0 && rd_data != cnt_rd_data[7:0] && rd_data_valid == 1'b1)begin
            error_flag <=  1'b1;
        end
    end

    assign status_led = error_flag ? 1'b1 : 1'b0;



    wire [255:0] probe0;
    assign probe0 = {
        cmd_trigger         ,
        cmd_type            ,
        cmd_trigger_dly     ,
        rx_data_shift       ,
        device_id           ,
        device_jdid         ,
        wr_flash_done       ,
        rd_flash_done       ,
        erase_flash_done    ,
        cmd_req             ,
        cmd_ack             ,
        wr_data             ,
        wr_data_pop         ,
        cnt_wr_data         ,
        cnt_rd_data         ,
        rd_data             ,
        rd_data_valid       ,
        flash_is_busy       ,
        flash_is_erased     ,
        error_flag
    };
    ila_0 ila_addr (
        .clk(clk), // input wire clk


        .probe0(probe0) // input wire [255:0] probe0
    );



endmodule