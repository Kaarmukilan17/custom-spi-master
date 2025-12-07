
`timescale 1ns/1ps

module Shift_Register_tb;

  // DUT I/O declarations
  reg        PCLK;
  reg        PRESETn;
  reg        ss;
  reg        receive_data;
  reg        send_data;
  reg        miso;
  reg        cpol;       // CPOL = 0
  reg        cphase;     // CPHA = 0
  reg        lsbfe;      // LSB first
  reg [7:0]  data_mosi;
  reg        flag_low, flag_high, flags_low, flags_high;
  wire [7:0] data_miso;
  wire       mosi;

  // Instantiate DUT
  Shift_Register DUT (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .ss(ss),
    .receive_data(receive_data),
    .send_data(send_data),
    .miso(miso),
    .cpol(cpol),
    .cphase(cphase),
    .lsbfe(lsbfe),
    .data_mosi(data_mosi),
    .flag_low(flag_low),
    .flag_high(flag_high),
    .flags_low(flags_low),
    .flags_high(flags_high),
    .data_miso(data_miso),
    .mosi(mosi)
  );

  // Generate clock: 20ns period (50 MHz)
  always #10 PCLK = ~PCLK;

  // === Tasks ===

  // Task: Initialize signals
  task initialize;
    begin
      PCLK = 0;
      PRESETn = 0;
      ss = 1;
      receive_data = 0;
      send_data = 0;
      miso = 0;
      cpol = 0;
      cphase = 0;
      lsbfe = 0;
      data_mosi = 8'h00;
      flag_low = 0;
      flag_high = 0;
      flags_low = 0;
      flags_high = 0;
    end
  endtask

  // Task: Reset the design
  task reset_dut;
    begin
      PRESETn = 0;
      #40;
      PRESETn = 1;
    end
  endtask

  // Task: Load data into shift register
  task load_data(input [7:0] din);
    begin
      data_mosi = din;
      send_data = 1;
      #20;
      send_data = 0;
    end
  endtask

  // Task: Drive one SPI clock cycle with correct flags
 task spi_cycle;
  input miso_bit;
  input integer idx;
  begin
    miso = miso_bit;  // ?? Place before sample

    flags_low  = 1;
    flag_low   = 1;
    #20;  // Rising edge: sample occurs here

    flags_low  = 0;
    flag_low   = 0;
    #20;  // Falling edge
  end
endtask


  // Task: Run 8-bit transmission
  task run_spi_transaction(input [7:0] mosi_data, input [7:0] miso_pattern);
    integer i;
    begin
      ss = 0;         // Pull SS low
      load_data(mosi_data);
      receive_data = 1;

      for (i = 0; i < 8; i = i + 1) begin //change
        spi_cycle(miso_pattern[i], i);
      end

      ss = 1;         // Pull SS high
      receive_data = 0;
    end
  endtask

  // === Test Sequence ===
initial begin
  initialize;
  reset_dut;

  
	//lsbfe=1; //comment if req
  
  run_spi_transaction(8'b01110101, 8'h63);  // MISO = 0x63 (0110_0011)

  #200;
  $finish;
end


  // === Monitor Outputs ===
  initial begin
    $monitor("Time=%0t | ss=%b mosi=%b miso=%b data_miso=%h flags_low=%b flag_low=%b",
             $time, ss, mosi, miso, data_miso, flags_low, flag_low);
  end

endmodule