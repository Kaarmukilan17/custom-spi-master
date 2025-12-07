
module baud_gen_tb();

  // DUT I/O
  reg PCLK, PRESETn, cpol, spiswai, ss, cphase;
  reg [1:0] spi_mode;
  reg [2:0] spr, sppr;

  wire [11:0] BaudRateDivisor;
  wire sclk, flag_low, flags_low, flag_high, flags_high;

  // Instantiate DUT
  test DUT (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .cpol(cpol),
    .spiswai(spiswai),
    .spi_mode(spi_mode),
    .spr(spr),
    .sppr(sppr),
    .ss(ss),
    .cphase(cphase),
    .BaudRateDivisor(BaudRateDivisor),
    .sclk(sclk),
    .flag_low(flag_low),
    .flags_low(flags_low),
    .flag_high(flag_high),
    .flags_high(flags_high)
  );

  // Clock generation: 50 MHz
  always #10 PCLK = ~PCLK;

  // === TASKS ===

  task initialize;
  begin
    PCLK = 0;
    PRESETn = 0;
    ss = 1;  // inactive
    cpol = 0;
    cphase = 0;
    spi_mode = 2'b00;  // spi_run
    sppr = 3'b000;
    spr  = 3'b000;
    spiswai = 0;
    #40;
    PRESETn = 1;
  end
  endtask

  task run_case(
    input reg [2:0] spr_in,
    input reg [2:0] sppr_in,
    input reg cp,
    input reg ph
  );
  begin
    $display("\n=== Running case: spr=%0d, sppr=%0d, CPOL=%b, CPHA=%b ===", spr_in, sppr_in, cp, ph);
    spr = spr_in;
    sppr = sppr_in;
    cpol = cp;
    cphase = ph;

    ss = 0;        // slave active
    spiswai = 0;
    spi_mode = 2'b00;

    #((2 * ((sppr + 1) * (1 << (spr + 1))) * 20) * 8); // 8 sclk cycles, 2 toggles each
    ss = 1;        // end transaction
  end
  endtask

  // === MAIN STIMULUS ===
 initial begin
  initialize;

  // Case 1: CPOL=0, CPHA=0, BaudRateDivisor=4
  run_case(3'b001, 3'b000, 0, 0); // spr=0, sppr=0 ? Div=2

 
  // Case 2: CPOL=1, CPHA=0, BaudRateDivisor=2
  run_case(3'b000, 3'b000, 1, 0); // spr=1, sppr=0 ? Div=4

  #100;
  $finish;
end


  // === MONITORING ===
  initial begin
    $monitor("Time=%0t | SCLK=%b | Div=%0d | Flags: fl=%b fh=%b fsl=%b fsh=%b | count=%b",
             $time, sclk, BaudRateDivisor, flag_low, flag_high, flags_low, flags_high, DUT.count);
  end

endmodule