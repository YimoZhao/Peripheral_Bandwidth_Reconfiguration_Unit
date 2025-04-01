////////////////////////////////////////////////////////////////////////////////
// Project Name    : Peripheral Bandwidth Reconfiguration Unit (PBRU)
// Module Name     : PBRU_IN_AGG
// Organization    : Boston University
// Author          : Yimo Zhao
// Create Date     : 02/13/2025
// Description     : 
//     This module aggregates narrow peripheral inputs into a wider internal
//     data bus for processing. It performs input-side bandwidth expansion by 
//     sequentially or concurrently merging data from multiple input channels,
//     buffering them as needed and aligning them to the target bus width.
// Key Features    :
//     - Multi-channel FIFO input interface
//     - Round-robin or configurable input scheduling
//     - Aggregated output aligned to processor data width
//
// Version         : 1.0
// Comments        : 
//     Designed for flexible bandwidth matching between low-bandwidth peripheral
//     sources and high-throughput compute cores.
////////////////////////////////////////////////////////////////////////////////
module PBRU_IN_AGG #(
    parameter INPUT_WIDTH  =16, 
    parameter SET_NUMBER   =64,
    parameter OUTPUT_WIDTH =INPUT_WIDTH * SET_NUMBER,
    parameter RAM_DEPTH    =16
) (
    input                               clk,
    input                               rst_n,
    //External Interface
    input                               i_ex_wr_valid,
    input       [INPUT_WIDTH-1:0]       i_ex_data,
    output wire                         o_ex_full,
    //Core Interface
    input                               i_co_rd_ready, 
    output reg                          o_co_data_valid,                          
    output wire [OUTPUT_WIDTH-1:0]      o_co_data,                              
    output wire                         o_co_empty                           
);

    localparam ADDR_WIDTH = $clog2(RAM_DEPTH);
    localparam SELE_WIDTH = $clog2(SET_NUMBER);

    wire [SET_NUMBER-1:0]   full_check;
    wire [SET_NUMBER-1:0]   empty_check;
    wire [ADDR_WIDTH:0]     wr_address      [SET_NUMBER-1:0];
    wire [ADDR_WIDTH:0]     rd_address      [SET_NUMBER-1:0];

    reg  [SELE_WIDTH-1:0]   wr_select;
    reg  [ADDR_WIDTH:0]     rd_pending; 

    genvar i;
    generate
        for (i = 0; i < SET_NUMBER; i = i + 1) begin: array_inst
            dual_port_ram_set#(
                .RAM_WIDTH      (INPUT_WIDTH),
                .RAM_DEPTH      (RAM_DEPTH)
            )ram_set_array(
                .clk            (clk),
                .rst_n          (rst_n),
                //Write
                .wr_en          (i_ex_wr_valid && (wr_select == i) && !o_ex_full),
                .data_in        (i_ex_data),
                .wr_addr        (wr_address[i]),
                //Read
                .rd_en          (o_co_data_valid && !o_co_empty),
                .data_out       (o_co_data[i*INPUT_WIDTH +: INPUT_WIDTH]),
                .rd_addr        (rd_address[i])
            );
        end
    endgenerate

    wire wr_round_end = (wr_select == (SET_NUMBER-1));

    //WRITE
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_select <= 'b0;
        end else begin
            if(i_ex_wr_valid && !o_ex_full) begin
                wr_select <= wr_round_end ? 'b0 : wr_select + 1'b1;
            end
        end
    end

    //READ
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            rd_pending      <= 'b0;
            o_co_data_valid <= 1'b0;
        end else begin
            //Processor hold
            if(!i_co_rd_ready) begin
                rd_pending <= wr_round_end ? rd_pending + 1'b1 : rd_pending;
                o_co_data_valid <= 1'b0;
            //Read ready
            end else begin
                //Read correctly after holding
                if(rd_pending > 0) begin
                    rd_pending <= wr_round_end ? rd_pending : rd_pending - 1'b1;
                    o_co_data_valid <= 1'b1;
                //Normal read
                end else begin
                    o_co_data_valid <= wr_round_end ? 1'b1 : 1'b0;
                end
            end
        end
    end

    //Full & Empty
    generate
        for (i = 0; i < SET_NUMBER; i = i + 1) begin
            assign full_check[i]  = (rd_address[i] == {~wr_address[i][ADDR_WIDTH],wr_address[i][ADDR_WIDTH-1:0]});
            assign empty_check[i] = (rd_address[i] == wr_address[i]);
        end
    endgenerate

    assign o_ex_full  = &full_check;
    assign o_co_empty = &empty_check;

endmodule
