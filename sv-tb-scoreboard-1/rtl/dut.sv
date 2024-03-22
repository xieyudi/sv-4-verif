// inspired by https://www.chipverify.com/systemverilog/systemverilog-testbench-example-1
module dut #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 16,
  parameter DEPTH = 256
) (
  input  logic clk,
  input  logic rst_n,
  input  logic vld_i,
  input  logic wr_i,
  input  logic [ADDR_WIDTH-1:0] addr_i,
  input  logic [DATA_WIDTH-1:0] wdata_i,
  output logic rdy_o,
  output logic [DATA_WIDTH-1:0] rdata_o
);
  logic [DEPTH-1:0][DATA_WIDTH-1:0] mem_q;
  
  logic rdy_q;
  logic rdy_set, rdy_clr;
  
  logic [DATA_WIDTH-1:0] rdata_q;
  
  always_ff @(posedge clk, negedge rst_n) begin: mem_wr
    if (~rst_n) begin
      for (int i = 0; i < DEPTH; i += 1) begin
        mem_q[i] <= 16'bx;
      end
    end else if (vld_i & rdy_q & wr_i) begin
      mem_q[addr_i] <= wdata_i;
    end
  end
  
  always_ff @(posedge clk, negedge rst_n) begin: mem_rd
    if (~rst_n) begin
      rdata_q <= 16'bx;
    end else if (vld_i & rdy_q & ~wr_i) begin
      rdata_q <= mem_q[addr_i];
    end
  end
  
  always_ff @(posedge clk, negedge rst_n) begin: rdy
    if (~rst_n) begin
      rdy_q <= 1'b1;
    end else begin
      rdy_q <= (rdy_q | rdy_set) & ~rdy_clr;
    end
  end
  
  assign rdy_set = ~rdy_q;
  assign rdy_clr = rdy_q & vld_i & ~wr_i;
  
  assign rdy_o = rdy_q;
  assign rdata_o = rdata_q;
  
endmodule

