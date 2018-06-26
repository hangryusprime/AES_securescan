`timescale 1ns / 1ps

module DFF(
           input wire reset_n, 
           input wire clk,
			  input wire D,
			  output reg Q
			  );

always @(posedge clk) begin
	if(reset_n == 1'b0) begin
		Q <= D;
		end
	else begin
		Q <= 1'b0;
		end
end
endmodule
