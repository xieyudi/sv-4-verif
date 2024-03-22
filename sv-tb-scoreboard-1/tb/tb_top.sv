`timescale 1ns/1ns
// https://www.chipverify.com/systemverilog/systemverilog-testbench-example-1

interface dutif #(
  parameter ADDR_WIDTH = 8,
  parameter DATA_WIDTH = 16,
  parameter DEPTH = 256
) (
  input logic clk
);
  logic vld;
  logic wr;
  logic [ADDR_WIDTH-1:0] addr;
  logic [DATA_WIDTH-1:0] wdata;
  logic rdy;
  logic [DATA_WIDTH-1:0] rdata;
endinterface

class transaction #(
  int ADDR_WIDTH = 8,
  int DATA_WIDTH = 16,
  int DEPTH = 256
);
  rand bit                  wr;
  rand bit [ADDR_WIDTH-1:0] addr;
  rand bit [DATA_WIDTH-1:0] wdata;
       bit [DATA_WIDTH-1:0] rdata;
  
  function void print(string tag = "");
    $display("T=%0t [%s] wr=%d addr=0x%0h wdata=0x%0h rdata=0x%0h", 
             $time, tag, wr, addr, wdata, rdata);
  endfunction
endclass

class driver;
  virtual dutif dutif_vif;
  event driver_done;
  mailbox driver_mbx;
  transaction transaction_obj;
  
  task run();
    $display("T=%0t [driver] starting...", $time);
    dutif_vif.vld = 1'b0;
    dutif_vif.wr = 1'b0;
    
    @(posedge dutif_vif.clk);
    
    forever begin
      $display("T=%0t [driver] waiting for transaction...", $time);
      
      driver_mbx.get(transaction_obj);
      transaction_obj.print("driver");
      
      dutif_vif.vld = 1'b1;
      dutif_vif.wr = transaction_obj.wr;
      dutif_vif.addr = transaction_obj.addr;
      dutif_vif.wdata = transaction_obj.wdata;
      
      do begin
      	@(posedge dutif_vif.clk);
      end while (~dutif_vif.rdy);
      
      dutif_vif.vld = 1'b0;
      ->driver_done;
    end
  endtask
  
endclass

class monitor;
  virtual dutif dutif_vif;
  mailbox scoreboard_mbx;
  
  task run();
    $display("T=%0t [monitor] starting...", $time);
    
    forever begin
      @(posedge dutif_vif.clk);
      if (dutif_vif.vld & dutif_vif.rdy) begin
        transaction transaction_obj = new();
        transaction_obj.wr = dutif_vif.wr;
        transaction_obj.addr = dutif_vif.addr;
        transaction_obj.wdata = dutif_vif.wdata;
        if (~dutif_vif.wr) begin
          @(posedge dutif_vif.clk);
          transaction_obj.rdata = dutif_vif.rdata;
        end
        $display("T=%0t [monitor] putting transaction to scoreboard_mbx", $time);
        scoreboard_mbx.put(transaction_obj);
      end
    end
  endtask
endclass

class scoreboard #(
  int ADDR_WIDTH = 8,
  int DATA_WIDTH = 16,
  int DEPTH = 256
);
  mailbox scoreboard_mbx;
  transaction transaction_obj;
  bit [DEPTH-1:0][DATA_WIDTH-1:0] board;
  
  task run();
    for (int i = 0; i < DEPTH; i += 1) begin
      board[i] = 16'bx;
    end
    
    forever begin
      scoreboard_mbx.get(transaction_obj);
      transaction_obj.print("scoreboard");
      
      if (transaction_obj.wr) begin
        board[transaction_obj.addr] = transaction_obj.wdata;
        $display("T=%0t [scoreboard] storing to board addr=0x%0h wdata=0x%0h", 
                 $time, transaction_obj.addr, transaction_obj.wdata);
      end
      
      if (~transaction_obj.wr) begin
        if (board[transaction_obj.addr] == 16'bx) begin
          $display("T=%0t [scoreboard] first time read addr=0x%0h rdata=0x%0h", 
                 $time, transaction_obj.addr, transaction_obj.rdata);
        end else begin
          if (board[transaction_obj.addr] == transaction_obj.rdata) begin
            $display("T=%0t [scoreboard] read match addr=0x%0h rdata=0x%0h", 
                 $time, transaction_obj.addr, transaction_obj.rdata);
          end else begin
            $display("T=%0t [scoreboard] read mismatch addr=0x%0h rdata(expected)=0x%0h rdata(actual)=0x%0h", 
                 $time, transaction_obj.addr, board[transaction_obj.addr], transaction_obj.rdata);
          end
        end
      end
    end
  endtask
endclass

class environment;
  driver d0;
  monitor m0;
  scoreboard s0;
  mailbox scoreboard_mbx;
  virtual dutif dutif_vif;
  
  function new();
    d0 = new();
    m0 = new();
    s0 = new();
    scoreboard_mbx = new();
  endfunction
  
  virtual task run();
    d0.dutif_vif = dutif_vif;
    m0.dutif_vif = dutif_vif;
    m0.scoreboard_mbx = scoreboard_mbx;
    s0.scoreboard_mbx = scoreboard_mbx;
    fork
      s0.run();
      m0.run();
      d0.run();
    join_any
  endtask
  
endclass

class test;
  environment e0;
  mailbox driver_mbx;
  
  function new();
    e0 = new();
    driver_mbx = new();
  endfunction
  
  virtual task run();
    e0.d0.driver_mbx = driver_mbx;
    fork
      e0.run();
    join_none
    
    apply_stimulus();
  endtask
  
  virtual task apply_stimulus();
    transaction transaction_obj;
    $display("T=%0t [test] applying stimulus...", $time);
    
    transaction_obj = new();
    transaction_obj.randomize() with {wr == 1'b1; addr == 8'haa;};
    driver_mbx.put(transaction_obj);
    
    transaction_obj = new();
    transaction_obj.randomize() with {wr == 1'b0; addr == 8'haa;};
    driver_mbx.put(transaction_obj);
  endtask
  
endclass

module tb_top;
  logic clk;
  logic rst_n;
  
  dutif dutif_if (clk);
  test t0;
  
  dut u_dut (
    .clk,
    .rst_n,
    .vld_i(dutif_if.vld),
    .wr_i(dutif_if.wr),
    .addr_i(dutif_if.addr),
    .wdata_i(dutif_if.wdata),
    .rdy_o(dutif_if.rdy),
    .rdata_o(dutif_if.rdata)
  );
  
  initial begin: crg
    clk = 1'b0;
    rst_n = 1'b0;
    #5;
    rst_n = 1'b1;
    forever #5 clk = ~clk;
  end
  
  initial begin
    t0 = new();
    t0.e0.dutif_vif = dutif_if;
    t0.run();
    
    #200 $finish;
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
  
endmodule
