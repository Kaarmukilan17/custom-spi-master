

module 	Shift_register(input PCLK,
input PRESETn,
input	ss,
input receive_data,
input send_data,
input miso,
input cpol,
input cphase,
input lsbfe,
input [7:0]data_mosi,
input flag_low,
input flag_high,
input flags_low,
input flags_high,
output [7:0]data_miso,
output reg mosi);  

reg [7:0] temp_reg,shift_register;
reg [2:0] count,count1,count2,count3;  
wire [3:0]sel0_1;
wire [3:0]sel2_3;


assign data_miso=receive_data?temp_reg:8'b0;


//mosi,Shift Register,temp_Reg //check this block for mosi logic

always @(posedge PCLK or negedge PRESETn )
 begin
	if (!PRESETn) begin
		temp_reg<=0;
		shift_register<=0;
	//check
		mosi<=1'b0;
			end

	else begin
		if (send_data) begin
		shift_register<=data_mosi;
	 	 end
		 
		 if (!ss) begin
			//if (flags_low | flags_high) begin 
				casex(sel0_1)  //modified logic for mosi
			//4'b00x0:mosi<=mosi;
				4'b00x1:if (flags_low) mosi<=shift_register[count1];//4'b010x:mosi<=mosi;
				4'b011x:if (flags_low) mosi<=shift_register[count];//4'b10x0:mosi<=mosi;
				4'b10x1:if (flags_high) mosi<=shift_register[count1];//4'b110x:mosi<=mosi;
				4'b111x:if (flags_high) mosi<=shift_register[count];
				endcase
			//end //add this logic for mosi if req
			if (flag_low | flag_high) begin 
			// this if condn is added only for miso mosi is already checking flags_hgh b4 updating
				casex(sel2_3)		//4'b00x0:temp_reg[count3]<=temp_reg[count3];
				4'b00x1:temp_reg[count3]<=(miso)&(flag_low) ;	//4'b010x:temp_reg[count2] <=temp_reg[count2] ;
				4'b011x:temp_reg[count2] <=(miso)&(flag_low) ;		//4'b10x0:temp_reg[count3]<=temp_reg[count3];
				4'b10x1:temp_reg[count3]<=(miso)&(flag_high);			//4'b110x:temp_reg[count2] <=temp_reg[count2] ;
				4'b111x:temp_reg[count2] <=(miso)&(flag_high);
				endcase
			end
		 end //ss block end
	end 	//preset block	 
end


//Logic for count,count1,2,3
assign sel0_1={cpol^cphase,lsbfe,(count<=3'd7),(count1>=3'd0)};
assign sel2_3={cpol^cphase,lsbfe,(count2<=3'd7),(count3>=3'd0)};
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
        count <= 3'd0;
        count1 <= 3'd7;
		  count2 <= 3'd0;
        count3 <= 3'd7;
        
    end
	 else begin
		 if (!ss) begin
		 //add default condn (allop assign in all cases-- count<=0;count1<=7;
			casex(sel0_1) //For transmitting
			4'b00x0:count1<=3'd7;
			4'b00x1:if (flags_low) count1<=(count1-1'b1);
			4'b010x:count<=3'd0;
			4'b011x:if (flags_low) count<=(count+1'b1);
			4'b10x0:count1<=3'd7;
			4'b10x1:if (flags_high) count1<=(count1-1'b1);
			4'b110x:count<=3'd0;
			4'b111x:if (flags_high) count<=(count+1'b1);
			endcase
			casex(sel2_3) //For receiving
			4'b00x0:count3<=3'd7;
			4'b00x1:if (flag_low) count3<=(count3-1'b1);
			4'b010x:count2<=3'd0;
			4'b011x:if (flag_low) count2<=(count2+1'b1);
			4'b10x0:count3<=3'd7;
			4'b10x1:if (flag_high) count3<=(count3-1'b1);
			4'b110x:count2<=3'd0;
			4'b111x:if (flag_high) count2<=(count2+1'b1);
			endcase
		 end //ss block end
	end 	//preset block	(else) 
end
	endmodule