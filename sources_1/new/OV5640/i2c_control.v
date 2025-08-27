module i2c_control(
  Clk,
  Rst_p,

  wrreg_req,
  rdreg_req,
  addr,
  addr_mode,
  wrdata,
  rddata,
  device_id,
  RW_Done,

  ack,

  i2c_sclk,
  i2c_sdat
);
  input Clk;
  input Rst_p;

  input wrreg_req;
  input rdreg_req;
  input [15:0] addr;
  input addr_mode;
  input [7:0] wrdata;
  output reg[7:0] rddata;
  input [7:0] device_id;
  output reg RW_Done;

  output reg ack;

  output i2c_sclk;
  inout i2c_sdat;

  reg [5:0]Cmd;
  reg [7:0]Tx_DATA;
  wire Trans_Done;
  wire ack_o;
  reg Go;
  wire [15:0] reg_addr;

  assign reg_addr = addr_mode?addr:{addr[7:0],addr[15:8]};

  wire [7:0]Rx_DATA;

  localparam 
    WR   = 6'b000001,   //Ð´ÇëÇó
    STA  = 6'b000010,   //ÆðÊ¼Î»ÇëÇó
    RD   = 6'b000100,   //¶ÁÇëÇó
    STO  = 6'b001000,   //Í£Ö¹Î»ÇëÇó
    ACK  = 6'b010000,   //Ó¦´ðÎ»ÇëÇó
    NACK = 6'b100000;   //ÎÞÓ¦´ðÇëÇó

  i2c_bit_shift i2c_bit_shift(
    .Clk       (Clk        ),
    .Rst_p     (Rst_p      ),
    .Cmd       (Cmd        ),
    .Go        (Go         ),
    .Rx_DATA   (Rx_DATA    ),
    .Tx_DATA   (Tx_DATA    ),
    .Trans_Done(Trans_Done ),
    .ack_o     (ack_o      ),
    .i2c_sclk  (i2c_sclk   ),
    .i2c_sdat  (i2c_sdat   )
  );

  reg [6:0]state;
  reg [7:0]cnt;

  localparam
    IDLE         = 7'b0000001,   //¿ÕÏÐ×´Ì¬
    WR_REG       = 7'b0000010,   //Ð´¼Ä´æÆ÷×´Ì¬
    WAIT_WR_DONE = 7'b0000100,   //µÈ´ýÐ´¼Ä´æÆ÷Íê³É×´Ì¬
    WR_REG_DONE  = 7'b0001000,   //Ð´¼Ä´æÆ÷Íê³É×´Ì¬
    RD_REG       = 7'b0010000,   //¶Á¼Ä´æÆ÷×´Ì¬
    WAIT_RD_DONE = 7'b0100000,   //µÈ´ý¶Á¼Ä´æÆ÷Íê³É×´Ì¬
    RD_REG_DONE  = 7'b1000000;   //¶Á¼Ä´æÆ÷Íê³É×´Ì¬

  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)begin
    Cmd <= 6'd0;
    Tx_DATA <= 8'd0;
    Go <= 1'b0;
    rddata <= 0;
    state <= IDLE;
    ack <= 0;
  end
  else begin
    case(state)
      IDLE:
        begin
          cnt <= 0;
          ack <= 0;
          RW_Done <= 1'b0;
          if(wrreg_req)
            state <= WR_REG;
          else if(rdreg_req)
            state <= RD_REG;
          else
            state <= IDLE;
        end

      WR_REG:
        begin
          state <= WAIT_WR_DONE;
          case(cnt)
            0:write_byte(WR | STA, device_id);
            1:write_byte(WR, reg_addr[15:8]);
            2:write_byte(WR, reg_addr[7:0]);
            3:write_byte(WR | STO, wrdata);
            default:;
          endcase
        end

      WAIT_WR_DONE:
        begin
          Go <= 1'b0; 
          if(Trans_Done)begin
            ack <= ack | ack_o;
            case(cnt)
              0: begin cnt <= 1; state <= WR_REG;end
              1: 
                begin 
                  state <= WR_REG;
                  if(addr_mode)
                    cnt <= 2; 
                  else
                    cnt <= 3;
                end

              2: begin
                  cnt <= 3;
                  state <= WR_REG;
                end
              3:state <= WR_REG_DONE;
              default:state <= IDLE;
            endcase
          end
        end

      WR_REG_DONE:
        begin
          RW_Done <= 1'b1;
          state <= IDLE;
        end

      RD_REG:
        begin
          state <= WAIT_RD_DONE;
          case(cnt)
            0:write_byte(WR | STA, device_id);
            1:if(addr_mode)
                write_byte(WR, reg_addr[15:8]);
              else
                write_byte(WR | STO, reg_addr[15:8]);
            2:write_byte(WR | STO, reg_addr[7:0]);
            3:write_byte(WR | STA, device_id | 8'd1);
            4:read_byte(RD | ACK | STO);
            default:;
          endcase
        end

      WAIT_RD_DONE:
        begin
          Go <= 1'b0; 
          if(Trans_Done)begin
            if(cnt <= 3)
              ack <= ack | ack_o;
            case(cnt)
              0: begin cnt <= 1; state <= RD_REG;end
              1: 
                begin 
                  state <= RD_REG;
                  if(addr_mode)
                    cnt <= 2; 
                  else
                    cnt <= 3;
                end
              2: begin
                  cnt <= 3;
                  state <= RD_REG;
                end
              3:begin
                  cnt <= 4;
                  state <= RD_REG;
                end
              4:state <= RD_REG_DONE;
              default:state <= IDLE;
            endcase
          end
        end

      RD_REG_DONE:
        begin
          RW_Done <= 1'b1;
          rddata <= Rx_DATA;
          state <= IDLE;        
        end
      default:state <= IDLE;
    endcase
  end

  task read_byte;
    input [5:0]Ctrl_Cmd;
    begin
      Cmd <= Ctrl_Cmd;
      Go <= 1'b1; 
    end
  endtask

  task write_byte;
    input [5:0]Ctrl_Cmd;
    input [7:0]Wr_Byte_Data;
    begin
      Cmd <= Ctrl_Cmd;
      Tx_DATA <= Wr_Byte_Data;
      Go <= 1'b1; 
    end
  endtask
endmodule