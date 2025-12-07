`timescale 1ns/1ps

module spi_slave_ctrl_tb;

  // Inputs
  reg PCLK, PRESETn;
  reg mstr, send_data, spiswai;
  reg [1:0] spi_mode;
  reg [11:0] baudratedivisor;

  // Outputs
  wire ss, tip, receive_data;

  // Instantiate DUT
  SPI_slave_control_select DUT (
    .PCLK(PCLK),
    .PRESETn(PRESETn),
    .mstr(mstr),
    .send_data(send_data),
    .spiswai(spiswai),
    .spi_mode(spi_mode),
    .baudratedivisor(baudratedivisor),
    .ss(ss),
    .tip(tip),
    .receive_data(receive_data)
  );

  // Clock generation: 50 MHz
  always #10 PCLK = ~PCLK;

  // === TASKS ===

  task initialize;
  begin
    PCLK = 0;
    PRESETn = 0;
    mstr = 0;
    send_data = 0;
    spiswai = 0;
    spi_mode = 2'b00;
    baudratedivisor = 12'd1; // target = 16
    #40;
    PRESETn = 1;
  end
  endtask

  task trigger_send;
  begin
    send_data = 1;
    #20;
    send_data = 0;
  end
  endtask

  task simulate_transaction(
    input [11:0] divisor,
    input bit master,
    input bit swai
  );
    begin
      $display("\n--- Simulation: baud_div=%0d, mstr=%b, spiswai=%b ---", divisor, master, swai);
      baudratedivisor = divisor;
      mstr = master;
      spiswai = swai;

      trigger_send(); // trigger ss low
      #((divisor << 4) * 20 + 100); // wait for receive_data to pulse
    end
  endtask

  // === STIMULUS ===
  initial begin
    initialize;

    // Case 1: Normal transaction, divisor = 1, target = 16
    simulate_transaction(12'd1, 1, 0);

    // Case 2: Longer transaction, divisor = 2, target = 32
    simulate_transaction(12'd2, 1, 0);

    // Case 3: spiswai disables transfer
    simulate_transaction(12'd1, 1, 1);

    // Case 4: not in master mode
    simulate_transaction(12'd1, 0, 0);

    #100;
    $finish;
  end

  // === MONITOR ===
  initial begin
    $monitor("Time=%0t | ss=%b tip=%b recv_data=%b | send_data=%b mstr=%b mode=%b count=%d",
             $time, ss, tip, receive_data, send_data, mstr, spi_mode, DUT.count);
  end

endmodule
