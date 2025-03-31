`timescale 1ns/1ps

module dual_port_ram_set #(
    parameter RAM_WIDTH = 32,
    parameter RAM_DEPTH = 16
) (
    input                               clk,
    input                               rst_n,
    //Write
    input                               wr_en,
    input      [RAM_WIDTH-1:0]          data_in,
    output reg [$clog2(RAM_DEPTH):0]    wr_addr,
    //Read
    input                               rd_en,
    output reg [RAM_WIDTH-1:0]          data_out,
    output reg [$clog2(RAM_DEPTH):0]    rd_addr
);

    localparam ADDR_WIDTH = $clog2(RAM_DEPTH);

    integer i;

    reg [RAM_WIDTH-1:0] ram_array [RAM_DEPTH-1:0];

    //WRITE
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            wr_addr <= 'b0;
            for(i=0;i<RAM_DEPTH;i=i+1) ram_array[i] <= {RAM_WIDTH{1'b0}};
        end else if(wr_en) begin
            wr_addr <= wr_addr + 1'b1;
            ram_array[wr_addr[ADDR_WIDTH-1:0]] <= data_in;
        end
    end

    //READ
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_addr  <= 'b0;
            data_out <= {RAM_WIDTH{1'b0}};
        end else if(rd_en) begin
            rd_addr  <= rd_addr + 1'b1;
            data_out <= ram_array[rd_addr[ADDR_WIDTH-1:0]];
        end
    end
    
endmodule