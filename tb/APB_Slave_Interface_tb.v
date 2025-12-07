
`timescale 1ns/1ps

module apb_slave_interface_tb;

  // DUT I/Os
  reg        PCLK, PRESETn;
  reg  [2:0] PADDR;
  reg        PWRITE, PSEL, PENABLE;
  reg  [7:0] PWDATA, miso_data;
  reg        ss, receive_data, tip;

  wire [7:0] PRDATA, mosi_data;
  wire       PREADY, PSLVERR, mstr, cpol, cpha, lsbfe, spiswai, send_data;
  wire [2:0] sppr, spr;
  wire [1:0] spi_mode;
  wire       spi_interrupt_request;

  // Instantiate DUT
  test DUT (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .PADDR(PADDR),
    .PWRITE(PWRITE),
    .PSEL(PSEL),
    .PENABLE(PENABLE),
    .PWDATA(PWDATA),
    .PRDATA(PRDATA),
    .PREADY(PREADY),
    .PSLVERR(PSLVERR),
    .mosi_data(mosi_data),
    .miso_data(miso_data),
    .ss(ss),
    .receive_data(receive_data),
    .tip(tip),
    .mstr(mstr),
    .cpol(cpol),
    .cpha(cpha),
    .lsbfe(lsbfe),
    .spiswai(spiswai),
    .sppr(sppr),
    .spr(spr),
    .spi_interrupt_request(spi_interrupt_request),
    .spi_mode(spi_mode),
    .send_data(send_data)
  );

  // Clock gen: 50 MHz
  always #10 PCLK = ~PCLK;

  // ==== TASKS ====
  task initialize;
    begin
      PCLK = 0;
      PRESETn = 0;
      PWRITE = 0; PSEL = 0; PENABLE = 0;
      PADDR = 3'b000; PWDATA = 8'h00;
      miso_data = 8'h00;
      ss = 0; receive_data = 0; tip = 0;
      #40 PRESETn = 1;
    end
  endtask

  task apb_write(input [2:0] addr, input [7:0] data);
    begin
      @(negedge PCLK);
      PWRITE = 1; PSEL = 1; PADDR = addr; PWDATA = data;
      @(negedge PCLK);
      PENABLE = 1;
      @(negedge PCLK);
      if (PREADY) $display("WRITE OK @ addr=%0d: data=0x%0h", addr, data);
      @(negedge PCLK);
      PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
  endtask

  task apb_read(input [2:0] addr);
    reg [7:0] data;
    begin
      @(negedge PCLK);
      PWRITE = 0; PSEL = 1; PADDR = addr;
      @(negedge PCLK);
      PENABLE = 1;
      @(negedge PCLK);
      data = PRDATA;
      if (PREADY) $display("READ OK  @ addr=%0d: data=0x%0h", addr, data);
      @(negedge PCLK);
      PSEL = 0; PENABLE = 0;
    end
  endtask

  // ==== STIMULUS ====
initial begin
  initialize;

  // === Control Register Tests ===

  // Write & Read CR1 (PADDR=0)
  apb_write(3'b000, 8'h1C);  // Set cpol/cpha/mstr/spe/spie
  apb_read(3'b000);

  // Write & Read CR2 (PADDR=1): set spiswai
  apb_write(3'b001, 8'b1000_0010); //PWDATA=82H
  apb_read(3'b001);

  // Write & Read BR (PADDR=2): set sppr=4, spr=3 (BaudRateDivisor)
  apb_write(3'b010, 8'b1100_0011); //PWDATA=C3H
  apb_read(3'b010);

  // === Data Register Interaction ===

  // 🟢 Write to SPI_DR before read test
  apb_write(3'b101, 8'h3C);  // Some TX data

  // Simulate MISO response: data comes back on read
  miso_data = 8'hA5;
  ss = 0; receive_data = 1; tip = 0;
  apb_read(3'b101);  // Expect SPI_DR contains 0xA5 if receive_data is active
  receive_data = 0; ss = 1;

  // === Interrupt Logic Test ===

  // Enable SPI interrupt (spie = 1)
  apb_write(3'b000, 8'b1000_0000);  // spie = 1

  miso_data = 8'hFF;
  ss = 0; receive_data = 1;
  apb_read(3'b101);  // Read SPI_DR to check interrupt flags
  receive_data = 0; ss = 1;

  #200;
  $finish;
end

  // ==== MONITOR ====
  initial begin
    $monitor("Time=%0t | PADDR=%0d PWDATA=%0h PRDATA=%0h PREADY=%b PSLVERR=%b | mist=%b cp=%b ch=%b lsb=%b swi=%b sppr=%d spr=%d intr=%b",
       $time, PADDR, PWDATA, PRDATA, PREADY, PSLVERR, mstr, cpol, cpha, lsbfe, spiswai, sppr, spr, spi_interrupt_request);
  end

endmodule