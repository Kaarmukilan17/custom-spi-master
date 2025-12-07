module APB_Slave_Interface (
    input         PCLK,
    input         PRESETn,
    input  [2:0]  PADDR,
    input         PWRITE,
    input         PSEL,
    input         PENABLE, 
    input  [7:0]  PWDATA,
    output reg [7:0]  PRDATA, //changed as reg
    output        PREADY,
    output        PSLVERR,

    output    reg  [7:0]  mosi_data,//changed as reg
    input      [7:0]   miso_data,
    input        ss,
	 
	input receive_data,
	input tip,
	output mstr,
	output cpol,
	output cpha,
	output lsbfe,
	output spiswai,
	output [2:0] sppr,
	output [2:0] spr,
	output reg spi_interrupt_request, //chnged as reg
	output reg [1:0]spi_mode, //reg [1:0] added extra
	output reg send_data);//changed as reg

reg [7:0] SPI_CR1;
reg [7:0] SPI_CR2;
reg [7:0] SPI_SR;
reg [7:0] SPI_DR;
reg [7:0] SPI_BR;

wire sptef;     // Transmit Register Empty
wire spif;      // Interrupt Flag
wire spe;       // SPI System Enable Bit
wire modfen;    // Master/Slave Mode Select Bit
wire modf;      // Fault Flag
wire ssoe;      // Slave Select Output Enable
wire wr_enb;
wire rd_enb;
wire spie;
wire sptie;     // Transmit Interrupt Enable


	parameter default_CR1=8'h04; //cpol=0,cphase=1 by default
	parameter cr2_mask = 8'b0001_1011;
	parameter default_CR2=8'h00; 
	parameter br_mask  = 8'b0111_0111;
	parameter default_BR=8'h00;
	parameter default_DR=8'h00;

// parameter declaration for SPI Mode States
parameter spi_run  = 2'b00;  // Run mode
parameter spi_wait = 2'b01;  // Wait mode
parameter spi_stop = 2'b10;  // Stop mode

// spi_mode
reg [1:0] next_mode;         // for SPI FSM
reg [1:0] STATE, next_state; // for APB FSM

// parameter declaration for APB States - to ensure correct timing and data integrity
parameter IDLE   = 2'b00; // Idle state
parameter SETUP  = 2'b01; // Setup state
parameter ENABLE = 2'b10; // Enable state



//FSM - SPI
  // State Register
always @(posedge PCLK or negedge PRESETn)
	begin
    if (!PRESETn)
      spi_mode <= spi_run;
    else
      spi_mode <= next_mode;
  end

  // Next-State Logic
always @(*) begin //spe given priority ,reverese if else if to crct logic
  next_mode=spi_mode;
    case (spi_mode)
      spi_run: begin
        if (!spe)
          next_mode = spi_wait;
			end
      spi_wait: begin
			if (spe)
				next_mode = spi_run;
			else if (spiswai)
				next_mode = spi_stop;
        //if (spiswai)   //  next_mode = spi_stop;   //else if (spe)    //  next_mode = spi_run;
			end
      spi_stop: begin
        if (spe)
          next_mode = spi_run;
        else if (!spiswai)
          next_mode = spi_wait;
         end
      default: next_mode = spi_run;
    endcase
 end


//FSM - APB-

always @(posedge PCLK or negedge PRESETn)
begin
if(!PRESETn)
	STATE<=IDLE;
else
	STATE<=next_state;
end
always @(STATE or PSEL or PENABLE )
begin
next_state=STATE;
case(STATE)
	IDLE:begin 
		if(PSEL && !PENABLE)next_state= SETUP;
		end
	SETUP:begin
		next_state=IDLE;
		if(PSEL && PENABLE)next_state= ENABLE;
		else if(PSEL && !PENABLE)next_state= SETUP;
		end
	ENABLE:begin
		next_state=IDLE;
		if(PSEL) next_state= SETUP;
	end
	endcase

end


//other connections 

//from cr1 
assign ssoe  = SPI_CR1[1];
assign mstr  = SPI_CR1[4];
assign spe   = SPI_CR1[6];
assign spie  = SPI_CR1[7];
assign sptie = SPI_CR1[5];
assign cpol  = SPI_CR1[3];
assign cpha  = SPI_CR1[2];
assign lsbfe = SPI_CR1[0];

//from cr2
assign modfen  = SPI_CR2[4];   // Mode Fault Enable Bit
assign spiswai = SPI_CR2[1];   // to stop the sclk generation if it is asserted

//from br
assign sppr = SPI_BR[6:4];
assign spr  = SPI_BR[2:0];


assign wr_enb = PWRITE && (STATE == ENABLE);//same as (PWRITE && (STATE == ENABLE))?1'b1:1'b0 both are same
assign rd_enb = !PWRITE && (STATE == ENABLE);
assign PREADY = (STATE == ENABLE) ? 1'b1 : 1'b0;
assign PSLVERR = (STATE == ENABLE) ? tip : 1'b0;

//STATUS REGISTER 

//Status flag bits
assign sptef=(SPI_DR==8'h00); 
assign spif =(SPI_DR!==8'h00);

//assign SPI_SR=(PRESETn)?8'b0010_0000:{spif,1'b0,sptef,modf,4'b0};
//Check in class- add address 3'b011

always @(*)
begin
SPI_SR=(!PRESETn)?8'b0010_0000:{spif,1'b0,sptef,modf,4'b0};  //changed here
end


//modf
assign modf = (~ss)&(mstr)&(modfen)&(~ssoe); 

//SPI INTERRUPT REQUEST -check in next class
//assign spi_interrupt_request=(!spie && !sptie)?0:(spie && !sptie)?(spif || modf):(!spie && sptie)?sptef:(spif||sptef||modf);
always @(*) begin
  case ({spie, sptie})
    2'b00: spi_interrupt_request = 1'b0;                           // No interrupt enabled
    2'b10: spi_interrupt_request = spif || modf;                  // Only SPI interrupt enabled
    2'b01: spi_interrupt_request = sptef;                         // Only TX interrupt enabled
    2'b11: spi_interrupt_request = spif || sptef || modf;         // Both interrupts enabled
    default: spi_interrupt_request = 1'b0;                       
  endcase
end

//Control Registers 1,2 ; Baud Rate Register
always @(posedge PCLK or negedge PRESETn )
 begin
	if (!PRESETn)
	begin
		SPI_CR1<=default_CR1;
		SPI_CR2<=default_CR2;
		SPI_BR<=default_BR;
	end
else if (wr_enb )
	begin
		if ((PADDR==3'b000))
			SPI_CR1<=PWDATA;
		if ((PADDR==3'b001))
			SPI_CR2<=(PWDATA& cr2_mask);
		if ((PADDR==3'b010))
			SPI_BR<=(PWDATA & br_mask);
	end	
/*else  begin //remove this block if clearing if not required
	SPI_CR1<=8'h00;
	SPI_CR2<=8'h04;
	SPI_BR<=8'h00;
	end */
end


wire run_or_wait;
assign run_or_wait=((spi_mode==spi_run)||(spi_mode==spi_wait));

//parameter spi_run  = 2'b00;  
//parameter spi_wait = 2'b01; 


//Data Register 
always @(posedge PCLK or negedge PRESETn )
 begin
	if (!PRESETn)
	begin
		SPI_DR<=default_DR;
	end
else if (!wr_enb )
	begin
		if (run_or_wait &&(SPI_DR==PWDATA) &&(SPI_DR!=miso_data))
			SPI_DR<=8'b0;
		else
			begin
			if (receive_data && run_or_wait)
				SPI_DR<=miso_data;	
			end	
	end	
else  begin 
		if ((PADDR==3'b101))
			SPI_DR<=PWDATA;
		end
	end 
//end

 
//send_data -WRITTEN ACC To MICROARCHITURE WILL CHANGE LATER
always @(posedge PCLK or negedge PRESETn )
 begin
	if (!PRESETn)
		send_data<=1'b0;
	else if (!wr_enb )
	  begin 
		if (run_or_wait &&(SPI_DR==PWDATA) &&(SPI_DR!=miso_data))
			send_data<=1'b1;
		else
			begin //remove this block if diagram wrong 0 0 in mux
			if (receive_data && run_or_wait)
				send_data<=0;
			else
				send_data<=0;
		end
	end 
end

//mosi_data block - given by sir  -check in next class
always@(posedge PCLK or negedge PRESETn)
begin
	if(!PRESETn)
	   mosi_data <= 0;
   else if ((SPI_DR == PWDATA) && (SPI_DR != miso_data) && (run_or_wait) && ~wr_enb) 
    	begin
      	 mosi_data <= SPI_DR;
		end
end

//PR DATA -ACC TO MICROARCHITECTURE 
always@(*)
	begin
		if (!rd_enb)
			PRDATA=8'b0;
		else if (PADDR==3'b000)
			PRDATA=SPI_CR1;
		else if (PADDR==3'b001)
			PRDATA=SPI_CR2;
		else if (PADDR==3'b010)
			PRDATA=SPI_BR;
		else if (PADDR==3'b011)
			PRDATA=SPI_SR;
		else if (PADDR==3'b101) //else PRDAT=SPI_DR;
			PRDATA=SPI_DR;
		else		
			PRDATA=8'b0 ;
		//here = or <= whihc is crct?
	end


	 endmodule

/*
	 //old logic 
module APB_Slave_Interface (
    input         PCLK,
    input         PRESETn,
    input  [2:0]  PADDR,
    input         PWRITE, 
    input         PSEL,
    input         PENABLE, 
    input  [7:0]  PWDATA,
    output reg [7:0]  PRDATA, //changed as reg
    output        PREADY,
    output        PSLVERR,

    output      [7:0]  mosi_data,
    input      [7:0]   miso_data,
    input        ss,
	 
	input receive_data,
	input tip,
	output mstr,
	output cpol,
	output cpha,
	output lsbfe,
	output spiswai,
	output [2:0] sppr,
	output [2:0] spr,
	output spi_interrupt_request,
	output reg [1:0]spi_mode, //reg [1:0] added extra
	output reg send_data);//changed as reg

reg [7:0] SPI_CR1;
reg [7:0] SPI_CR2;
reg [7:0] SPI_SR;
reg [7:0] SPI_DR;
reg [7:0] SPI_BR;

wire sptef;     // Transmit Register Empty
wire spif;      // Interrupt Flag
wire spe;       // System Enable Bit
wire modfen;    // Master/Slave Mode Select Bit
wire modf;      // Fault Flag
wire ssoe;      // Slave Select Output Enable
wire wr_enb;
wire rd_enb;
wire spie;
wire sptie;     // Transmit Interrupt Enable

parameter cr2_mask = 8'b0001_1011;
parameter br_mask  = 8'b0111_0111;

// parameter declaration for SPI Mode States
parameter spi_run  = 2'b00;  // Run mode
parameter spi_wait = 2'b01;  // Wait mode
parameter spi_stop = 2'b10;  // Stop mode

// spi_mode
reg [1:0] next_mode;         // for SPI FSM
reg [1:0] STATE, next_state; // for APB FSM

// parameter declaration for APB States - to ensure correct timing and data integrity
parameter IDLE   = 2'b00; // Idle state
parameter SETUP  = 2'b01; // Setup state
parameter ENABLE = 2'b10; // Enable state




//FSM - SPI

  // State Register
  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
      spi_mode <= spi_run;
    else
      spi_mode <= next_mode;
  end

  // Next-State Logic
  always @(*) begin
  next_mode=spi_mode;
    case (spi_mode)
      spi_run: begin
        if (!spe)
          next_mode = spi_wait;

      end

      spi_wait: begin
        if (spiswai)
          next_mode = spi_stop;
        else if (spe)
          next_mode = spi_run;
        
      end

      spi_stop: begin
        if (spe)
          next_mode = spi_run;
        else if (!spiswai)
          next_mode = spi_wait;
        
      end

      default: next_mode = spi_run;
    endcase
  end


//FSM - APB-


always @(posedge PCLK or negedge PRESETn)
begin
if(!PRESETn)
	STATE<=IDLE;
else
	STATE<=next_state;
end
always @(STATE or PSEL or PENABLE )
begin
next_state=STATE;
case(STATE)
IDLE:begin 
if(PSEL && !PENABLE)next_state= SETUP;
	end
SETUP:begin
next_state=IDLE;
if(PSEL && PENABLE)next_state= ENABLE;
		else if(PSEL && !PENABLE)next_state= SETUP;
		end
ENABLE:begin
next_state=IDLE;
if(PSEL) next_state= SETUP;
end
endcase

end



//other connections 
//from cr1 
assign ssoe  = SPI_CR1[1];
assign mstr  = SPI_CR1[4];
assign spe   = SPI_CR1[6];
assign spie  = SPI_CR1[7];
assign sptie = SPI_CR1[5];
assign cpol  = SPI_CR1[3];
assign cpha  = SPI_CR1[2];
assign lsbfe = SPI_CR1[0];
//from cr2
assign modfen  = SPI_CR2[4];   // Mode Fault Enable Bit
assign spiswai = SPI_CR2[1];   // to stop the sclk generation if it is asserted
//from br
assign sppr = SPI_BR[6:4];
assign spr  = SPI_BR[2:0];


assign wr_enb = PWRITE && (STATE == ENABLE);//same as (PWRITE && (STATE == ENABLE))?1'b1:1'b0 both are same
assign rd_enb = !PWRITE && (STATE == ENABLE);
assign PREADY = (STATE == ENABLE) ? 1'b1 : 1'b0;
assign PSLVERR = (STATE == ENABLE) ? tip : 1'b0;

//modf
assign modf = (~ss)&(mstr)&(modfen)&(~ssoe);


//STATUS REGISTER 

//Status flag bits
assign sptef=(SPI_DR==8'h00); 
assign spif =(SPI_DR!==8'h00);


//assign SPI_SR=(PRESETn)?8'b0010_0000:{spif,1'b0,sptef,modf,4'b0};
always @(*)
begin
SPI_SR=(PRESETn)?8'b0010_0000:{spif,1'b0,sptef,modf,4'b0};
end



//CONTROL REGISTER 1
 
	parameter default_CR1=8'h04;
wire [7:0]w;
reg [7:0]temp;
assign w=wr_enb?((PADDR==3'b000)?PWDATA:SPI_CR1):8'h00;
always @(posedge PCLK ) begin
temp<=w;
end 
  always@(*) begin
 SPI_CR1<=PRESETn?temp:default_CR1;
 end
 
 
 
//CONTROL REGISTER 2


	//parameter cr2_mask = 8'b0001_1011;
	parameter default_CR2=8'h00;
wire [7:0]w2;
reg [7:0]temp2;
assign w2=wr_enb?((PADDR==3'b001)?(PWDATA & cr2_mask):SPI_CR2):8'h04;
always @(posedge PCLK ) begin
temp2<=w2;
end 
  always@(*) begin
 SPI_CR2<=PRESETn?temp2:default_CR2;
 end


//BAUD RATE REGISTER
//parameter br_mask  = 8'b0111_0111;
	parameter default_BR=8'h00;
wire [7:0]w3;
reg [7:0]temp3;
assign w3=wr_enb?((PADDR==3'b010)?(PWDATA & br_mask):SPI_BR):8'h00;
always @(posedge PCLK ) begin
temp3<=w3;
end 
  always@(*) begin
 SPI_BR<=PRESETn?temp3:default_BR;
 end


//DATA REGISTER


	parameter default_DR=8'h0;
wire [7:0]w5,w6,w7;
wire w4;
reg [7:0]temp4;
//parameter spi_run  = 2'b00;  
//parameter spi_wait = 2'b01; 
assign w4=(spi_mode==spi_run)|(spi_mode==spi_wait);
assign w5=(receive_data&w4)?miso_data:SPI_DR;
assign w6=(w4 &(SPI_DR==PWDATA) &(SPI_DR!=miso_data))?8'b0:w5;
assign w7=wr_enb?((PADDR==3'b101)?PWDATA:SPI_DR):w6;
always @(posedge PCLK ) begin
temp4<=w7;
end 
  always@(*) begin
 SPI_DR<=PRESETn?temp4:default_DR;
 end

//SENDDATA 
	
	parameter default_senddata=1'b0;
wire w8,w9,w10,w11;
reg temp5;


assign w8=(spi_mode==spi_run)|(spi_mode==spi_wait);
assign w9=(receive_data&w8)?1:0;
assign w10=(w8 &(SPI_DR==PWDATA) &(SPI_DR!=miso_data))?1'b1:w9;
assign w11=wr_enb?(send_data):w10;


always @(posedge PCLK ) begin
temp5<=w11;
end 
  always@(*) begin
 send_data<=PRESETn?temp5:default_senddata;
 end




// PR DATA

 
always@(*)
begin
if (!rd_enb)
PRDATA=8'b0;
else if (PADDR==3'b000)
PRDATA=SPI_CR1;
else if (PADDR==3'b001)
PRDATA=SPI_CR2;
else if (PADDR==3'b010)
PRDATA=SPI_BR;
else if (PADDR==3'b011)
PRDATA=SPI_SR;
else
PRDATA=SPI_DR;
end
 

endmodule



//>>>>>>> f292b2665c870c8ecc0cfd027fcdfc95e88f6a34
*/