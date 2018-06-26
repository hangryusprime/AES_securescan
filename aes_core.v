
module aes_core(
                input wire            clk,
                input wire            reset_n,
		        input wire            encdec,
                input wire            init,
                input wire            next,
			    input wire            keylen,
			    input wire            enableScanIn,
				input wire            enableScanOut,
				input wire            loadkey,
				input wire            scan_mode,
                input wire [255 : 0]  key,
                input wire [127 : 0]  plaintext,

                output reg [127 : 0] ciphertext,
				output reg [127 : 0] ScanOut,
				output wire           ready,
                output wire           result_valid,
				output wire           faults,
				output wire [255 : 0] mux_key,
				output wire [127 : 0] ScanIn
               );

wire [255:0] test_key;
wire [127:0] param6;
assign faults = (enableScanIn | enableScanOut | ~loadkey)&( ~enableScanIn | ~enableScanOut | loadkey);
assign mux_key = (loadkey == 1) ? key : test_key;
assign test_key = (keylen == 1) ? param2 : param1;
parameter param1 = {param3,(128'hz)};
parameter param2 = {param3,param3};
parameter param3 = 128'h30303030304861727368613030303030;
parameter param4 = 128'hb72b9cdb6330f947c36462aa274c0cfe;
parameter param5 = 128'h613094199cda154b20c216dd0944002f;

assign param6 = (keylen == 1) ? param5 : param4;
assign ScanIn = (enableScanIn == 1) ? param6 : plaintext;


                         
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE  = 2'h0;
  localparam CTRL_INIT  = 2'h1;
  localparam CTRL_NEXT  = 2'h2;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0] aes_core_ctrl_reg;
  reg [1 : 0] aes_core_ctrl_new;
  reg         aes_core_ctrl_we;

  reg         result_valid_reg;
  reg         result_valid_new;
  reg         result_valid_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            init_state;

  wire [127 : 0] round_key;
  wire           key_ready;

  reg            enc_next;
  wire [3 : 0]   enc_round_nr;
  wire [127 : 0] enc_new_block;
  wire           enc_ready;
  wire [31 : 0]  enc_sboxw;

  reg            dec_next;
  wire [3 : 0]   dec_round_nr;
  wire [127 : 0] dec_new_block;
  wire           dec_ready;

  reg [127 : 0]  muxed_new_block;
  reg [3 : 0]    muxed_round_nr;
  reg            muxed_ready;

  wire [31 : 0]  keymem_sboxw;

  reg [31 : 0]   muxed_sboxw;
  wire [31 : 0]  new_sboxw;


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_encipher_block enc_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(enc_next),

                               .keylen(keylen),
                               .round(enc_round_nr),
                               .round_key(round_key),

                               .sboxw(enc_sboxw),
                               .new_sboxw(new_sboxw),

                               .block(ScanIn),
                               .new_block(enc_new_block),
                               .ready(enc_ready)
                              );


  aes_decipher_block dec_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(dec_next),

                               .keylen(keylen),
                               .round(dec_round_nr),
                               .round_key(round_key),

                               .block(ScanIn),
                               .new_block(dec_new_block),
                               .ready(dec_ready)
                              );


  aes_key_mem keymem(
                     .clk(clk),
                     .reset_n(reset_n),

                     .key(mux_key),
                     .keylen(keylen),
                     .init(init),

                     .round(muxed_round_nr),
                     .round_key(round_key),
                     .ready(key_ready),

                     .sboxw(keymem_sboxw),
                     .new_sboxw(new_sboxw)
                    );


  aes_sbox sbox(.sboxw(muxed_sboxw), .new_sboxw(new_sboxw));


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready        = ready_reg;
  always @ (posedge result_valid) begin
  ciphertext <= muxed_new_block;
  end
  assign result_valid = result_valid_reg;
  always @ (posedge clk) begin
	  if(scan_mode == 1) begin
		  if(enableScanOut ==1) begin
			  ScanOut <= muxed_new_block;
		  end
	  end
  end
  


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin: reg_update
      if (!reset_n)
        begin
          result_valid_reg  <= 1'b0;
          ready_reg         <= 1'b1;
          aes_core_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin
          if (result_valid_we)
            begin
              result_valid_reg <= result_valid_new;
            end

          if (ready_we)
            begin
              ready_reg <= ready_new;
            end

          if (aes_core_ctrl_we)
            begin
              aes_core_ctrl_reg <= aes_core_ctrl_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // sbox_mux
  //
  // Controls which of the encipher datapath or the key memory
  // that gets access to the sbox.
  //----------------------------------------------------------------
  always @*
    begin : sbox_mux
      if (init_state)
        begin
          muxed_sboxw = keymem_sboxw;
        end
      else
        begin
          muxed_sboxw = enc_sboxw;
        end
    end // sbox_mux


  //----------------------------------------------------------------
  // encdex_mux
  //
  // Controls which of the datapaths that get the next signal, have
  // access to the memory as well as the block processing result.
  //----------------------------------------------------------------
  always @*
    begin : encdec_mux
      enc_next = 0;
      dec_next = 0;

      if (encdec)
        begin
          // Encipher operations
          enc_next        = next;
          muxed_round_nr  = enc_round_nr;
          muxed_new_block = enc_new_block;
          muxed_ready     = enc_ready;
        end
      else
        begin
          // Decipher operations
          dec_next        = next;
          muxed_round_nr  = dec_round_nr;
          muxed_new_block = dec_new_block;
          muxed_ready     = dec_ready;
        end
    end // encdec_mux


  //----------------------------------------------------------------
  // aes_core_ctrl
  //
  // Control FSM for aes core. Basically tracks if we are in
  // key init, encipher or decipher modes and connects the
  // different submodules to shared resources and interface ports.
  //----------------------------------------------------------------
  always @*
    begin : aes_core_ctrl
      init_state        = 0;
      ready_new         = 0;
      ready_we          = 0;
      result_valid_new  = 0;
      result_valid_we   = 0;
      aes_core_ctrl_new = CTRL_IDLE;
      aes_core_ctrl_we  = 0;

      case (aes_core_ctrl_reg)
        CTRL_IDLE:
          begin
            if (init)
              begin
                init_state        = 1;
                ready_new         = 0;
                ready_we          = 1;
                result_valid_new  = 0;
                result_valid_we   = 1;
                aes_core_ctrl_new = CTRL_INIT;
                aes_core_ctrl_we  = 1;
              end
            else if (next)
              begin
                init_state        = 0;
                ready_new         = 0;
                ready_we          = 1;
                result_valid_new  = 0;
                result_valid_we   = 1;
                aes_core_ctrl_new = CTRL_NEXT;
                aes_core_ctrl_we  = 1;
              end
          end

        CTRL_INIT:
          begin
            init_state = 1;

            if (key_ready)
              begin
                ready_new         = 1;
                ready_we          = 1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1;
              end
          end

        CTRL_NEXT:
          begin
            init_state = 0;

            if (muxed_ready)
              begin
                ready_new         = 1;
                ready_we          = 1;
                result_valid_new  = 1;
                result_valid_we   = 1;
                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1;
             end
          end

        default:
          begin

          end
      endcase // case (aes_core_ctrl_reg)

    end // aes_core_ctrl
endmodule // aes_core

//======================================================================
// EOF aes_core.v
//======================================================================
