module SPI_slave_control_select(
input PCLK,
input PRESETn,
input mstr,
input send_data,
input spiswai,
input [1:0] spi_mode,
input [11:0]baudratedivisor,
output reg ss,
output tip,
output reg receive_data
//,output reg rcv //comment this
);

reg rcv;
wire [15:0]target;
//parameter target=16'b0;
reg [15:0] count;
parameter spi_run  = 2'b00;  
parameter spi_wait = 2'b01;

//target
assign target=baudratedivisor << 4; //multiply by 16 - u get 8 sclk cycles (8 high 8 low -16)
wire run_or_wait;
assign run_or_wait=((spi_mode==spi_run)||(spi_mode==spi_wait));

assign tip=!ss;

//receive_Data logic
always @(posedge PCLK or negedge PRESETn)
	begin
    if (!PRESETn)
      receive_data <= 1'b0;
    else
      receive_data <= rcv;
  end
  
//rcv
always @(posedge PCLK or negedge PRESETn)
	begin
    if (!PRESETn)
      rcv <= 1'b0;
    else 
	 begin
		if (!((run_or_wait)&& (!spiswai)&&(mstr))) 
		rcv<=0;
		else if (send_data)
		rcv<=0;
		else if (!(count<=target-1'b1))
		rcv<=0;
		else if (count==target-1'b1)
		rcv<=1'b1;
		//else		rcv<=rcv;
	 end
  end
 
//ss ss=0 slave is selected
always @(posedge PCLK or negedge PRESETn)
	begin
    if (!PRESETn)
      ss <= 1'b1;
    else 
	 begin
		if (!((run_or_wait)&& (!spiswai)&&(mstr))) 
		ss<=1'b1;
		else if (send_data)
		ss<=0;
		else // if (!(count<=target-1'b1))
		ss<= (!(count<=target-1'b1)); //ss<=1'b1 // else //ss<=0;
	 end
  end
 
//count

always @(posedge PCLK or negedge PRESETn)
	begin
    if (!PRESETn)
      count <= 16'hffff;
    else 
	 begin
		if (!((run_or_wait)&& (!spiswai)&&(mstr))) 
		count<=16'hffff;
		else if (send_data)
		count<=16'b0;
		else if (!(count<=target-1'b1))
		count<= 16'hffff;
		else
		count<=count+1'b1;
	 end
  end
 

endmodule

