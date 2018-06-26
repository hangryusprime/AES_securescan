`timescale 1ns / 1ps

module securescan(
                input wire            clk,
                input wire            reset_n,
			       input wire            secure_mode,
                input wire            encdec,
                input wire            init,
                input wire            next,
			       input wire            keylen,
					 input wire            test_mode,
                input wire [255 : 0]  key,
                input wire [127 : 0]  plaintext,
				output wire           ready,
				output wire           result_valid,
                output wire [127 : 0] ciphertext,
					 output wire [127 : 0] ScanOut,
                output wire           faults,
                output wire [255 : 0] mux_key,
					 output wire [127 : 0] ScanIn					 
               );
					
wire enableScanIn;
wire enableScanOut;
wire loadkey;
wire scan_mode;

assign Reset = reset_n;

aes_core AES(
                .clk(clk),
                .reset_n(Reset),
					 .encdec(encdec),
					 .init(init),
					 .next(next),
					 .keylen(keylen),
					 .enableScanIn(enableScanIn),						
		          .enableScanOut(enableScanOut),
                .loadkey(loadkey),
                .scan_mode(scan_mode),
					 .key(key),
					 .plaintext(plaintext),
					 .ciphertext(ciphertext),
					 .ScanOut(ScanOut),
					 .ready(ready),
					 .result_valid(result_valid),
					 .faults(faults),
					 .mux_key(mux_key),
					 .ScanIn(ScanIn)
					 );
					 
testcontroller TC(
                  .clk(clk),
                  .secure_mode(secure_mode),
						.test_mode(test_mode),         
                  .reset_n(reset_n),					
                  .enableScanIn(enableScanIn),						
		            .enableScanOut(enableScanOut),
                  .loadkey(loadkey),
                  .scan_mode(scan_mode)						
						);
endmodule