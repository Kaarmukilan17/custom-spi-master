

module Baud_Rate_Generator(
input PCLK,
input PRESETn,
input cpol,
input spiswai,
input [1:0] spi_mode,
input [2:0]spr,
input [2:0]sppr,
input ss,
input cphase,

output [11:0] BaudRateDivisor,
output reg sclk,
output reg flag_low,
output reg flags_low,
output reg flag_high,
output reg flags_high
 );
 reg [2:0]count;
 wire pre_sclk; //depends on idle low/high
 
 assign BaudRateDivisor=((sppr+1'b1)*(2'b10)**(spr+1'b1)); //note:^ not power ** is power
 // assign BaudRateDivisor=((sppr+1)*2**(spr+1)); //note:^ not power ** is power

 assign pre_sclk=cpol;
 
 parameter [1:0]spi_run=2'b00;
 parameter[1:0] spi_wait=2'b01;
 
//Serial clock sclk and count generation
always @(posedge PCLK or negedge PRESETn)
begin
if (!PRESETn)begin
	count<=3'b0;
	sclk<=pre_sclk;
	end
else if ((!ss)&&(spi_mode==spi_run || spi_mode==spi_wait)&&(!spiswai))
	begin 
		if (count==BaudRateDivisor-1'b1)
			begin
			count<=3'b0;
			sclk<=~sclk;
			end
		else 
			count<=count+1'b1;
	end
else 
begin 
	count<=3'b0; //replace else if by else
	sclk<=pre_sclk;
end

end

//Data Receive Flag generation (flag_low and flag_high)

always @(posedge PCLK or negedge PRESETn)
begin
if (!PRESETn) 
begin 
	flag_low<=0;
	flag_high<=0;
end
else if ((cpol&&!cphase)||(!cpol&&cphase)) //xor right?
		begin 
			if(sclk && (count==BaudRateDivisor-1))
				flag_high<=1;
			else
				flag_high<=0;
		end
 else 
		begin
			if(!sclk && (count==BaudRateDivisor-1))
				flag_low<=1;
			else
				flag_low<=0;
		end
 
 end
 

//Data Transmit Flag generation (flags_low and flags_high) s-for send
//crct acc to microarchitecture
/*
always @(posedge PCLK or negedge PRESETn)
begin
if (!PRESETn) 
begin 
	flags_low<=0;
	flags_high<=0;
end
else if ((cpol&&!cphase)||(!cpol&&cphase)) //xor right?
		begin 
			if(sclk && (count==BaudRateDivisor-2))
				flags_high<=1;
			else
				flags_high<=0;
		end
 else 
		begin
			if(!sclk && (count==BaudRateDivisor-2))
				flags_low<=1;
			else
				flags_low<=0;
		end
  end
*/
 //crct acc to displayed waveform
 
 always @(posedge PCLK or negedge PRESETn)
begin
if (!PRESETn) 
begin 
	flags_low<=0;
	flags_high<=0;
end
else if ((cpol&&!cphase)||(!cpol&&cphase)) //xor right?
		begin 
			if(!sclk && (count==BaudRateDivisor-2))//change sclk !-_
				flags_high<=1;
			else
				flags_high<=0;
		end
 else 
		begin
			if(sclk && (count==BaudRateDivisor-2))//chaneg sclk _-!
				flags_low<=1;
			else
				flags_low<=0;
		end
  end
 
 
 
endmodule