// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Author 	 : WCC 1530604142@qq.com
// File   	 : spi_wr_rd
// Create 	 : 2023-03-01
// Revise 	 : 2023-
// Editor 	 : Vscode, tab size (4)
// Version	 : v1.0  initial
// Functions : spi basic write or read 
// License	  : License: LGPL-3.0-or-later
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
module spi_wr_rd(
    input   wire            clk             ,
    input   wire            rst             ,
    input   wire            cmd_start       ,
    input   wire    [7:0]   cmd             ,
    input   wire    [23:0]  cmd_addr        ,
    input   wire    [7:0]   wr_data         ,
    input   wire    [2:0]   addr_len        ,// using this to decide command with address or not, command like WREN/WRSR/RDSR/WRFR/RDFR 
                                             // don't have address.   
    input   wire    [31:0]  wr_len          ,
    output  reg             wr_data_pop     ,
    output  reg             wr_done         ,

    output  reg     [7:0]   rd_data         ,
    input   wire    [31:0]  rd_len          ,
    output  reg             rd_data_valid   ,
    output  reg             rd_done         ,

    output  wire            busy            ,

    output  reg             spi_clk         ,
    output  reg             spi_cs_n        ,
    output  reg             spi_mosi        ,
    input   wire            spi_miso        
);

    //====================================================
    // parameter define
    //====================================================
    localparam  IDLE        = 4'd0;
    localparam  ARBIT       = 4'd1;
    localparam  WR_START    = 4'd2;
    localparam  WR_COMMAND  = 4'd3;
    localparam  WR_ADDR     = 4'd4;
    localparam  WR_DATA     = 4'd5;
    localparam  WR_STOP     = 4'd6;
    localparam  RD_START    = 4'd7;
    localparam  RD_COMMAND  = 4'd8;
    localparam  RD_ADDR     = 4'd9;
    localparam  RD_DATA     = 4'd10;
    localparam  RD_STOP     = 4'd11;


    localparam [7:0] CMD_RDSR   = 8'h05;
    localparam [7:0] CMD_WREN   = 8'h06;
    localparam [7:0] CMD_ERASE  = 8'hD7;
    localparam [7:0] CMD_PP     = 8'h02;
    localparam [7:0] CMD_NORD   = 8'h03;
    localparam [7:0] CMD_RDID   = 8'hAB;
    localparam [7:0] CMD_RDJDID = 8'h9F;

    //====================================================
    //internal signals and registers
    //====================================================
    reg     [3:0]   state;
    reg     [1:0]   clk_div_counter ;
    wire            clk_rising_edge ;
    wire            clk_falling_edge;
    reg     [7:0]   tx_temp_reg     ;
    reg     [7:0]   rx_temp_reg     ;
    reg     [31:0]  cnt_wr_bytes       ;
    reg     [4:0]   cnt_wr_bits        ;

    reg     [31:0]  cnt_rd_bytes       ;
    reg     [4:0]   cnt_rd_bits        ;


    //----------------states------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    state <= ARBIT;
                end

                ARBIT : begin
                    if (cmd_start && (cmd == CMD_WREN || cmd == CMD_ERASE || cmd == CMD_PP)) begin
                        // if need to start a write operation
                        state <= WR_START;
                    end else if (cmd_start && (cmd == CMD_RDSR || cmd == CMD_NORD || cmd == CMD_RDID || cmd == CMD_RDJDID)) begin
                        // if need a read operation
                        state <= RD_START;
                    end
                end

                WR_START : begin
                    state <= WR_COMMAND;
                end

                WR_COMMAND : begin
                    if (addr_len == 'd0 && wr_len == 'd0 && cnt_wr_bits == 'd7  && clk_falling_edge) begin
                        // command like WREN is send
                        state <= WR_STOP;
                    end else if (addr_len == 'd0 && wr_len != 'd0 && cnt_wr_bits == 'd7  && clk_falling_edge) begin
                        // command like WRSR, WRFR is send, we need to program the register
                        state <= WR_DATA;
                    end else if (cnt_wr_bits == 'd7  && clk_falling_edge) begin
                        // command like pp is send, we need to program the flash
                        state <= WR_ADDR;
                    end
                end

                WR_ADDR : begin
                    if(wr_len != 'd0 && cnt_wr_bytes == 3-1 && clk_falling_edge && cnt_wr_bits == 'd7 )begin
                        // address has been writen into spi bus, start to program the flash
                        state <= WR_DATA;
                    end else if(wr_len == 'd0 && cnt_wr_bytes == 3-1 && clk_falling_edge && cnt_wr_bits == 'd7 )begin
                        // command like erase is send, stop write operation
                        state <= WR_STOP;
                    end
                end

                WR_DATA : begin
                    if(cnt_wr_bits == 'd7 && cnt_wr_bytes == wr_len-1 && clk_falling_edge)begin
                        // all data has been programmed into flash, stop a write operation
                        state <= WR_STOP;
                    end
                end

                WR_STOP : begin
                    state <= ARBIT;
                end


                RD_START : begin
                    state <= RD_COMMAND;
                end

                RD_COMMAND: begin
                    if (cnt_wr_bits == 'd7 && addr_len == 'd0 && clk_falling_edge) begin
                        // command like RDJDID,RDSR, RDFR is send, this is indicate by wr_len is zero, when 
                        // normal write operation， the write len is 3bytes address bytes.
                        state <= RD_DATA;
                    end else if (cnt_wr_bits == 'd7  && clk_falling_edge) begin
                        // command like NORD is send, we need to prepare for receiving data from flash
                        state <= RD_ADDR;
                    end
                end

                RD_ADDR : begin
                    if(cnt_wr_bytes == 3-1 && cnt_wr_bits == 'd7 && clk_falling_edge) begin
                        // all datas of a read operation has been read out from flash, stop a read operation
                        state <= RD_DATA;
                    end
                end

                RD_DATA : begin
                    if(cnt_rd_bytes == rd_len-1 && cnt_rd_bits == 'd7 && clk_falling_edge) begin
                        // all datas of a read operation has been read out from flash, stop a read operation
                        state <= RD_STOP;
                    end
                end

                RD_STOP : begin
                    state <= ARBIT;
                end
            endcase
        end
    end

    //----------------counter------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            clk_div_counter <= 'd0;
        end else if (state == WR_COMMAND || state == WR_ADDR || state == WR_DATA || state == RD_COMMAND || state == RD_ADDR || state == RD_DATA) begin
            clk_div_counter <= clk_div_counter + 1'b1;
        end else begin
            clk_div_counter <=  'd0;
        end
    end

    assign clk_rising_edge = clk_div_counter == 'd1;
    assign clk_falling_edge = clk_div_counter == 'd3;

    //----------------spi_cs_n------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            spi_cs_n <= 1'b1;
        end else if (state == WR_START || state == RD_START) begin
            spi_cs_n <= 1'b0;
        end else if (state == WR_STOP || state == RD_STOP) begin
            spi_cs_n <= 1'b1;
        end
    end

    //----------------spi_clk------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            spi_clk <= 1'b0;
        end else if (state == WR_COMMAND || state == WR_ADDR || state == WR_DATA || state == RD_COMMAND || state == RD_ADDR || state == RD_DATA) begin
            if (clk_rising_edge) begin
                spi_clk <= 1'b1;
            end else if (clk_falling_edge) begin
                spi_clk <= 1'b0;
            end
        end else begin
            spi_clk <=  1'b0;
        end
    end

    //----------------tx_temp_reg------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            tx_temp_reg <= 'd0;
        end else if (state == WR_START) begin
            // preparing for command
            tx_temp_reg <= cmd;
        end else if (state == RD_START) begin
            // preparing for command
            tx_temp_reg <= cmd;
        end else if (state == WR_ADDR) begin
            // write the address
            case (cnt_wr_bytes)
                0: tx_temp_reg <= cmd_addr[23:16];
                1: tx_temp_reg <= cmd_addr[15:8];
                2: tx_temp_reg <= cmd_addr[7:0];
                default : tx_temp_reg <= 'd0;
            endcase
        end else if (state == RD_ADDR) begin
            case (cnt_wr_bytes)
                0: tx_temp_reg <= cmd_addr[23:16];
                1: tx_temp_reg <= cmd_addr[15:8];
                2: tx_temp_reg <= cmd_addr[7:0];
                default : tx_temp_reg <= 'd0;
            endcase
        end else if(state == WR_DATA)begin
            // perparing for data, register the data pop from fifo
            tx_temp_reg <= wr_data;
        end
    end

    //----------------wr_data_pop------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            wr_data_pop <= 1'b0;
        end else if (state == WR_DATA && cnt_wr_bytes <= wr_len-1 &&  cnt_wr_bits == 'd7 && clk_falling_edge) begin
            // when one byte of data is written into flash, need to pop another data from fifo
            wr_data_pop <= 1'b1;
        end else begin
            wr_data_pop <=  1'b0;
        end
    end

    //----------------mosi-----------------
    always @(*) begin
        case (state)
            WR_COMMAND, WR_ADDR, RD_ADDR, RD_COMMAND, WR_DATA : begin
                // send data to spi bus when send command and data, MSB first
                spi_mosi = tx_temp_reg[7-cnt_wr_bits];
            end

            default: begin
                spi_mosi = 1'b0;
            end
        endcase
    end

    //----------------cnt_wr_bits------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_wr_bits <= 'd0;
        end else if (state == WR_COMMAND || state == WR_ADDR || state == WR_DATA || state == RD_COMMAND || state == RD_ADDR || state == RD_DATA) begin
            // when send command or data, we need to start a counter for how many bits has 
            // been send into the spi bus, when cnt bits reaches 8bit(byte), this cnt_wr_bits
            // counter needs to be clear.
            if (cnt_wr_bits == 'd7 && clk_falling_edge) begin
                cnt_wr_bits <= 'd0;
            end else if(clk_falling_edge)begin
                cnt_wr_bits <= cnt_wr_bits + 1'b1;
            end
        end
    end

    //----------------cnt_bytes------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_wr_bytes <= 'd0;
        end else if (state == WR_ADDR || state == RD_ADDR) begin
            // counter for how many address bytes have been sent into spi bus
            if (cnt_wr_bytes == 3-1 && cnt_wr_bits == 'd7 && clk_falling_edge) begin
                cnt_wr_bytes <= 'd0;
            end else if (cnt_wr_bits == 'd7 && clk_falling_edge) begin
                cnt_wr_bytes <= cnt_wr_bytes + 1'b1;
            end
        end  else if (state == WR_DATA) begin
            // counter for how many bytes has been programed into flash,
            // when on pp is finished, we need clear the counter
            if (cnt_wr_bytes == wr_len-1 && cnt_wr_bits == 'd7 && clk_falling_edge) begin
                cnt_wr_bytes <= 'd0;
            end else if (cnt_wr_bits == 'd7 && clk_falling_edge) begin
                cnt_wr_bytes <= cnt_wr_bytes + 1'b1;
            end
        end 
    end

    //----------------wr_done------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            wr_done <= 1'b0;
        end else if (state == WR_STOP) begin
            wr_done <= 1'b1;
        end else begin
            wr_done <=  1'b0;
        end
    end

    //----------------cnt_rx_bit------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_rd_bits <= 'd0;
        end else if (state == RD_DATA) begin
            // we capture the miso data at the falling edge of clock
            if (cnt_rd_bits == 'd7 && clk_falling_edge) begin
                cnt_rd_bits <= 'd0;
            end else if (clk_falling_edge) begin
                cnt_rd_bits <= cnt_rd_bits + 1'b1;
            end
        end
    end

    //----------------cnt_rd_bytes------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            cnt_rd_bytes <= 'd0;
        end else if (state == RD_DATA) begin
            // when we have read enough data from flash, we should clear this counter
            if (cnt_rd_bytes == rd_len -1 && cnt_rd_bits == 'd7 && clk_falling_edge) begin
                cnt_rd_bytes <= 'd0;
            end else if (cnt_rd_bits == 'd7 && clk_falling_edge) begin
                cnt_rd_bytes <= cnt_rd_bytes + 1'b1;
            end
        end
    end

    //----------------rx_temp_reg------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rx_temp_reg  <= 'd0;
        end else if (state == RD_DATA && clk_falling_edge) begin
            // shift the miso data into a register
            rx_temp_reg  <= {rx_temp_reg[6:0], spi_miso};
        end
    end

    //----------------rd_data_valid------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rd_data_valid <= 1'b0;
            rd_data <= 'd0;
        end else if (state == RD_DATA && clk_falling_edge && cnt_rd_bits == 'd7) begin
            // when 8bits data is shifted into a register
            rd_data_valid <= 1'b1;
            rd_data <= {rx_temp_reg[6:0], spi_miso};
        end else begin
            rd_data_valid <=  1'b0;
        end
    end

    //----------------rd_done------------------
    always @(posedge clk ) begin
        if (rst==1'b1) begin
            rd_done <= 1'b0;
        end else if (state == RD_STOP) begin
            rd_done <= 1'b1;
        end else begin
            rd_done <=  1'b0;
        end
    end


    assign busy = (state > ARBIT) ? 1'b1 : 1'b0;

endmodule