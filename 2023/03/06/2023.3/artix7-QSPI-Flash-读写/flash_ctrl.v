// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : spi_wr_rd
// Create 	 : 2023-03-01
// Revise 	 : 2023-
// Editor 	 : Vscode, tab size (4)
// Version	 : v1.0  initial
// Functions : flash ctrl. This module is used for multi boot.
//             When received a erase command, this module will erase from 0x800000
//             to 0xFFFFFF
//             When received a PP command, this module will start to program the 
//             BIN file into flash from 0x800000
//             When received a read command, this module will read the data from 
//             Flash.
//             When received a Read ID command, this module will pop the device ID
// License	  : License: LGPL-3.0-or-later
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
module flash_ctrl(
    input   wire            clk                 ,
    input   wire            rst                 ,
    input   wire    [5:0]   cmd_type            ,
    input   wire            cmd_req             ,
    output  reg             cmd_ack             ,
    input   wire    [31:0]  total_bytes_to_pp   ,
    input   wire    [7:0]   wr_data             ,
    output  wire            wr_data_pop         ,
    output  wire            wr_flash_done       ,
    input   wire    [31:0]  total_bytes_to_erase,
    output  wire            erase_flash_done    ,
    input   wire    [31:0]  total_bytes_to_rd   ,
    output  wire    [7:0]   rd_data             ,
    output  wire            rd_data_valid       ,
    output  wire            rd_flash_done       ,

    output  wire            flash_is_busy       ,
    output  wire            spi_clk             ,
    output  wire            spi_cs_n            ,
    output  wire            spi_mosi            ,
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


    localparam IDLE         = 4'd0;
    localparam ARBIT        = 4'd1;
    localparam RDSR         = 4'd2;
    localparam DEVICE_READY = 4'd3;
    localparam WREN         = 4'd4;
    localparam WREN_CHECK   = 4'd5;
    localparam ERASE        = 4'd6;
    localparam ERASE_CHECK  = 4'd7;
    localparam ERASE_RDSR   = 4'd8;
    localparam WR_DATA      = 4'd9;
    localparam PP_CHECK     = 4'd10;
    localparam WR_RDSR      = 4'd11;
    localparam RD_DATA      = 4'd12;

    localparam [7:0] CMD_RDSR   = 8'h05;
    localparam [7:0] CMD_WREN   = 8'h06;
    localparam [7:0] CMD_ERASE  = 8'hD7;
    localparam [7:0] CMD_PP     = 8'h02;
    localparam [7:0] CMD_NORD   = 8'h03;
    localparam [7:0] CMD_RDID   = 8'hAB;
    localparam [7:0] CMD_RDJDID = 8'h9F;

    //====================================================
    // internal signals and registers
    //====================================================

    reg     [3:0]       state               ;
    reg     [3:0]       state_dly           ;//this is for debug propose

    reg     [2:0]       addr_len            ;
    reg                 cmd_start           ;
    reg     [7:0]       cmd                 ;
    reg     [24:0]      wr_len              ;
    reg     [23:0]      cmd_addr            ;
    wire                wr_done             ;
    reg     [24:0]      rd_len              ;
    wire                rd_done             ;
    wire                busy                ;

    reg     [31:0]      wr_bytes_left       ;
    reg     [31:0]      wr_addr             ;
    reg     [31:0]      bytes_erased        ;
    reg     [31:0]      erase_bytes_left    ;
    reg     [31:0]      erase_addr          ;
    reg     [31:0]      bytes_read          ;
    reg     [31:0]      rd_bytes_left       ;
    wire                rd_flash_valid      ;


    //----------------state------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= IDLE;
        end else  begin
            case (state)
                IDLE : begin
                    state = ARBIT;
                end

                ARBIT : begin
                    if(cmd_req) begin
                        state <= RDSR;
                    end
                end

                RDSR : begin
                    if (rd_done && rd_data[0] == 1'b0) begin
                        state <= DEVICE_READY;
                    end else if (rd_done && rd_data[0] == 1'b1) begin
                        state <= ARBIT;
                    end
                end

                DEVICE_READY : begin
                    case(cmd_type)
                        CMD_TYPE_ERASE, CMD_TYPE_WR_DATA : state <= WREN;
                        CMD_TYPE_RDID, CMD_TYPE_RDJDID, CMD_TYPE_RD_DATA : state <= RD_DATA;
                        default : state <= DEVICE_READY;
                    endcase
                end

                WREN : begin
                    if(wr_done) begin
                        state <= WREN_CHECK;
                    end 
                end

                WREN_CHECK : begin
                    if(rd_done && rd_data[1:0] == 2'b10 && cmd_type == CMD_TYPE_ERASE)begin
                        state <= ERASE;
                    end else if (rd_done && rd_data[1:0] == 2'b10 && cmd_type == CMD_TYPE_WR_DATA) begin
                        state <= WR_DATA;
                    end
                end

                ERASE : begin
                    if(wr_done )begin
                        state <= ERASE_CHECK;
                    end
                end

                ERASE_CHECK : begin
                    if(erase_bytes_left != 0) begin
                        state <= ERASE_RDSR;
                    end else if (erase_bytes_left == 0) begin
                        state <= ARBIT;
                    end
                end

                ERASE_RDSR : begin
                    if(rd_done && rd_data[0] == 1'b0)begin
                        state <= WREN;
                    end
                end

                WR_DATA : begin
                    if(wr_done)begin
                        state <= PP_CHECK;
                    end
                end

                PP_CHECK : begin
                    if(wr_bytes_left != 0) begin
                        state <= WR_RDSR;
                    end else if (wr_bytes_left == 0) begin
                        state <= ARBIT;
                    end 
                end

                WR_RDSR : begin
                    if(rd_done && rd_data[0] == 1'b0)begin
                        state <= WREN;
                    end
                end


                RD_DATA : begin
                    if(rd_done)begin
                        state <= ARBIT;
                    end
                end

                default : begin
                    state <= IDLE;
                end
            endcase
        end 
    end

    //----------------cmd_start/cmd/wr_len/rd_len/addr_len------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cmd_start <= 1'b0;
        end begin
            if (state == ARBIT && cmd_req == 1'b1) begin
                // in arbit state, we need to check the flash status,
                // so we need to RDSR command to get the status
                cmd_start <= 1'b1;
                cmd <= CMD_RDSR;
                addr_len <= 'd0;
                rd_len <= 'd1;
                cmd_addr <= 'd0;
            end else if (state == RDSR && rd_done) begin
                // if the device is busy, we need to keep checking the status
                if (rd_data[0] != 1'b0) begin
                    cmd_start <= 1'b1;
                    cmd <= CMD_RDSR;
                    addr_len <= 'd0;
                    cmd_addr <= 'd0;
                    rd_len <= 1'b1;
                end
            end else if (state == DEVICE_READY) begin
                // if the device is ready, start to prepare a command for write or read
                case (cmd_type)
                    CMD_TYPE_ERASE, CMD_TYPE_WR_DATA: begin
                        // if we want to write or erase flash, needs send a WREN command first
                        cmd_start <= 1'b1;
                        cmd <= CMD_WREN;
                        addr_len <= 'd0;
                        wr_len <= 'd0;
                        cmd_addr <= 'd0;
                    end

                    CMD_TYPE_RDID: begin
                        // send the read device ID command
                        cmd_start <= 1'b1;
                        cmd <= CMD_RDID;
                        addr_len <= 'd3;
                        rd_len <= 'd1;
                        cmd_addr <= 'd0;
                    end

                    CMD_TYPE_RDJDID: begin
                        // send the read device JDID comamnd
                        cmd_start <= 1'b1;
                        cmd <= CMD_RDJDID;
                        addr_len <= 'd0;
                        rd_len <= 'd3;
                        cmd_addr <= 'd0;
                    end

                    CMD_TYPE_RD_DATA: begin
                        //send read data command
                        cmd_start <= 1'b1;
                        cmd <= CMD_NORD;
                        addr_len <= 'd3;
                        rd_len <= total_bytes_to_rd;
                        cmd_addr <= 'd0;
                    end

                    default : begin
                        cmd_start <= 1'b0;
                        cmd <= ERASE;
                        addr_len <= 'd0;
                        rd_len <= 'd0;
                        wr_len <= 'd0;
                        cmd_addr <= 'd0;
                    end
                endcase
            end else if (state == WREN && wr_done == 1'b1) begin
                // when WREN is send, check the status of this device
                cmd_start <= 1'b1;
                cmd <= CMD_RDSR;
                addr_len <= 'd0;
                cmd_addr <= 'd0;
                rd_len <= 1'b1;
            end else if (state == WREN_CHECK && rd_done) begin
                // if device is busy, we need keep checking the device's status
                if (rd_data[1:0] != 2'b10) begin
                    cmd_start <= 1'b1;
                    cmd <= CMD_RDSR;
                    addr_len <= 'd0;
                    cmd_addr <= 'd0;
                    rd_len <= 1'b1;
                end else if (rd_data[1:0] == 2'b10 && cmd_type == CMD_TYPE_ERASE) begin
                    // if the device is ready to erase, we can start a erase command
                    cmd_start <= 1'b1;
                    cmd <= CMD_ERASE;
                    addr_len <= 'd3;
                    cmd_addr <= erase_addr;
                    wr_len <= 'd0;
                end else if (rd_data[1:0] == 2'b10 && cmd_type == CMD_TYPE_WR_DATA) begin
                    // if the device is ready to PP, we can start a PP command
                    cmd_start <= 1'b1;
                    cmd <= CMD_PP;
                    addr_len <= 'd3;
                    cmd_addr <= wr_addr;
                    wr_len <= (wr_bytes_left > 256) ? 256 : wr_bytes_left;
                end
            end else if (state == PP_CHECK && wr_bytes_left != 'd0) begin
                // If there are still data needs  to be written into flash, so we need to check the device's 
                // status for another PP
                cmd_start <= 1'b1;
                cmd <= CMD_RDSR;
                addr_len <= 'd0;
                cmd_addr <= 'd0;
                wr_len <= 'd0;
            end else if (state == WR_RDSR && rd_done) begin
                // if the device is busy, keep checking the status
                if (rd_data[0] != 1'b0) begin
                    cmd_start <= 1'b1;
                    cmd <= CMD_RDSR;
                    addr_len <= 'd0;
                    cmd_addr <= 'd0;
                    rd_len <= 1'b1;
                end else if (rd_data[0] == 1'b0) begin
                    // if the device is ready, we can start another wriite process
                    cmd_start <= 1'b1;
                    cmd <= CMD_WREN;
                    addr_len <= 'd0;
                    cmd_addr <= 'd0;
                    wr_len <= 'd0;
                end
            end else if (state == ERASE_CHECK && erase_bytes_left != 'd0) begin
                // If there are still data needs  to be erased, so we need to check the device's 
                // status for another erase
                cmd_start <= 1'b1;
                cmd <= CMD_RDSR;
                addr_len <= 'd0;
                cmd_addr <= 'd0;
                wr_len <= 'd0;
            end else if (state == ERASE_RDSR && rd_done) begin
                // if the device is busy, keep checking the status
                if (rd_data[0] != 1'b0) begin
                    cmd_start <= 1'b1;
                    cmd <= CMD_RDSR;
                    addr_len <= 'd0;
                    cmd_addr <= 'd0;
                    rd_len <= 1'b1;
                end else if (rd_data[0] == 1'b0) begin
                    // if the device is ready, we can start another Erase process
                    cmd_start <= 1'b1;
                    cmd <= CMD_WREN;
                    addr_len <= 'd0;
                    cmd_addr <= 'd0;
                    wr_len <= 'd0;
                end
            end else begin
                cmd_start <= 1'b0;
            end
        end 
    end

    //----------------wr_bytes_left------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            wr_bytes_left <= 'd0;
            wr_addr <= 'd0;
        end else if (state == DEVICE_READY && cmd_type == CMD_TYPE_WR_DATA ) begin
            wr_bytes_left <= total_bytes_to_pp;
            wr_addr <= 'd0;
        end else if (state == WR_DATA && wr_done) begin
            wr_bytes_left <= wr_bytes_left - wr_len;
            wr_addr <= wr_addr + wr_len;
        end
    end

    //----------------erase_bytes_left------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            erase_bytes_left <= 'd0;
            erase_addr <= 'd0;
        end else if (state == DEVICE_READY && cmd_type == CMD_TYPE_ERASE ) begin
            erase_bytes_left <= total_bytes_to_erase;
            erase_addr <= 'd0;
        end else if (state == ERASE && wr_done) begin
            erase_bytes_left <= erase_bytes_left - 32'h1000;
            erase_addr <= erase_addr + 32'h1000;
        end
    end

    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rd_bytes_left <= 'd0;
        end else if (state == DEVICE_READY && cmd_type == CMD_TYPE_RD_DATA ) begin
            rd_bytes_left <= total_bytes_to_rd;
        end else if (state == RD_DATA && rd_flash_valid) begin
            rd_bytes_left <= rd_bytes_left - 1'b1;
        end
    end

    //----------------cmd_ack------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cmd_ack <= 1'b0;
        end else if (state == RDSR &&  rd_done && rd_data[0] == 1'b0) begin
            cmd_ack <= 1'b1;
        end else begin
            cmd_ack <=  1'b0;
        end
    end

    assign flash_is_busy = (state != IDLE && state != ARBIT && state != DEVICE_READY) ? 1'b1 : 1'b0;

    spi_wr_rd u_spi_wr_rd(
        .clk            ( clk            ),
        .rst            ( rst            ),
        .cmd_start      ( cmd_start      ),
        .cmd            ( cmd            ),
        .cmd_addr       ( cmd_addr       ),
        .wr_data        ( wr_data        ),
        .addr_len       ( addr_len       ),
        .wr_len         ( wr_len         ),
        .wr_data_pop    ( wr_data_pop    ),
        .wr_done        ( wr_done        ),
        .rd_data        ( rd_data        ),
        .rd_len         ( rd_len         ),
        .rd_data_valid  ( rd_flash_valid  ),
        .rd_done        ( rd_done        ),
        .busy           (                ),
        .spi_clk        ( spi_clk        ),
        .spi_cs_n       ( spi_cs_n       ),
        .spi_mosi       ( spi_mosi       ),
        .spi_miso       ( spi_miso       )
    );

    assign wr_flash_done = (state == PP_CHECK && wr_bytes_left == 0);
    assign erase_flash_done = (state == ERASE_CHECK && erase_bytes_left == 0);
    assign rd_flash_done = (state == RD_DATA && rd_done == 1'b1);
    assign rd_data_valid = (state == RD_DATA && rd_flash_valid == 1'b1);


    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state_dly <= 'd0;
        end else begin
            state_dly <= state;
        end 
    end


    // wire [255:0] probe0;
    // assign probe0 = {
    //     cmd_type    ,
    //     cmd_req     ,
    //     cmd_ack     ,
    //     spi_clk     ,
    //     spi_cs_n    ,
    //     spi_mosi    ,
    //     spi_miso    ,
    //     flash_is_busy,
    //     wr_flash_done,
    //     rd_flash_done,
    //     state,
    //     state_dly,
    //     addr_len,
    //     cmd_start,
    //     cmd,
    //     wr_len,
    //     cmd_addr,
    //     wr_done,
    //     rd_len,
    //     rd_done,
    //     rd_data,
    //     rd_flash_valid,
        
    //     erase_bytes_left,
    //     erase_addr
    // };
    // ila_0 u_ila_0 (
    //     .clk(clk), // input wire clk
    
    
    //     .probe0(probe0) // input wire [255:0] probe0
    // );


endmodule