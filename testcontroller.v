`timescale 1ns / 1ps

module testcontroller(
                input wire            clk,
				    input wire            secure_mode,
					 input wire            test_mode,
					 input wire            reset_n,
                output wire           enableScanIn,
				    output wire           enableScanOut,
				    output wire           loadkey,
				    output wire           scan_mode
               );
wire FFin;
wire FFout;
					
DFF register(
             .reset_n(reset_n),
             .clk(clk),
				 .D(FFin),
				 .Q(FFout));

assign FFin = secure_mode | FFout;
assign loadkey = FFout;
assign enableScanIn = ~FFout;
assign enableScanOut = ~FFout;
assign scan_mode = test_mode & ~FFout;

endmodule

module DFF(
           input wire clk,
			  input wire reset_n,
			  input wire D,
			  output reg Q
			  );

always @ (posedge clk) begin
	if(reset_n == 1) begin
		Q <= D;
		end
	else begin
		Q <= 1'b0;
		end
end
endmodule