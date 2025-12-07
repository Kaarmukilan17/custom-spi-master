`timescale 1ns/1ps
module SPI_with_APB_top_tb;

  // Clock & reset
  reg PCLK, PRESETn;
  initial begin
    PCLK = 0;
    forever #5 PCLK = ~PCLK;
  end

  // APB signals
  reg [2:0] PADDR;
  reg PWRITE, PSEL, PENABLE;
  reg [7:0] PWDATA;
  wire [7:0] PRDATA;
  wire PREADY, PSLVERR;

  // SPI signals
  reg miso;
  wire ss, sclk, mosi, spi_interrupt_request;

  // Instantiate DUT
  SPI_with_APB_topmodule DUT (
    .PCLK(PCLK), .PRESETn(PRESETn),
    .PADDR(PADDR), .PWRITE(PWRITE), .PSEL(PSEL), .PENABLE(PENABLE),
    .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY), .PSLVERR(PSLVERR),
    .miso(miso), .ss(ss), .sclk(sclk), .mosi(mosi), .spi_interrupt_request(spi_interrupt_request)
  );

  // === Tasks ===

  // Reset task
  task reset;
    begin
      #10 PRESETn = 0;
      #10 PRESETn = 1;
    end
  endtask

  // APB Write task
  task apb_write(input [2:0] addr, input [7:0] data);
    begin
      @(posedge PCLK);
      PADDR = addr; PWRITE = 1; PSEL = 1; PENABLE = 0; PWDATA = data;
      @(posedge PCLK);
      PENABLE = 1;
      wait(PREADY);
      @(posedge PCLK);
      PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
  endtask

  // APB Read task
  task apb_read(input [2:0] addr);
    begin
      @(posedge PCLK);
      PADDR = addr; PWRITE = 0; PSEL = 1; PENABLE = 0;
      @(posedge PCLK);
      PENABLE = 1;
      wait(PREADY);
      @(posedge PCLK);
      $display("READ @ %0t ns -> ADDR=%0d DATA=0x%0h", $time, addr, PRDATA);
      PSEL = 0; PENABLE = 0;
    end
  endtask

  // Write all config registers
  task write_registers(input [7:0] cr1, input [7:0] cr2, input [7:0] br);
    begin
      apb_write(3'b000, cr1); // CR1
      apb_write(3'b001, cr2); // CR2
      apb_write(3'b010, br);  // BR
    end
  endtask

  // Send MISO bits MSB-first
  task miso_bits_msb(input [7:0] data);
    integer i;
    begin
      wait(~ss);
      for (i = 7; i >= 0; i = i - 1) begin
        @(posedge sclk);
        miso = data[i];
      end
    end
  endtask

  // Send MISO bits LSB-first
  task miso_bits_lsb(input [7:0] data);
    integer i;
    begin
      wait(~ss);
      for (i = 0; i < 8; i = i + 1) begin
        @(posedge sclk);
        miso = data[i];
      end
    end
  endtask

  // === Main Stimulus ===
  initial begin
    // Initialize
    PWRITE = 0; PSEL = 0; PENABLE = 0; PWDATA = 0; PADDR = 0;
    miso = 0;
    reset;

    // === Set CR1 = 0x1C = SPE + MSTR + CPHA, CR2 = 0, BR = 0
    write_registers(8'h1C, 8'h00, 8'h00);

    // === Transmit 8'hb9 ===
    apb_write(3'b101, 8'hB9); // SPI_DR ? 0xA5//A5= 01

    // === Receive 0x65 on MISO, MSB-first ===
    #20;
    fork
      miso_bits_msb(8'h65);
    join

    // === Read back SPI_DR (should contain 0x3C)
    #20;
    apb_read(3'b101);

    #100;
    $finish;
  end

  // Monitor
  initial $monitor("T=%0t | ss=%b sclk=%b mosi=%b miso=%b PRDATA=0x%0h",
                   $time, ss, sclk, mosi, miso, PRDATA);

endmodule
