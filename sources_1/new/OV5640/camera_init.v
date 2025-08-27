module camera_init#
(
  parameter IMAGE_WIDTH  = 640,
  parameter IMAGE_HEIGHT = 720,
  parameter IMAGE_FLIP_EN   = 0,
  parameter IMAGE_MIRROR_EN = 0
)
(
  Clk,
  Rst_p,

  Init_Done,
  camera_rst_n,
  camera_pwdn,

  i2c_sclk,
  i2c_sdat
);
  input Clk;
  input Rst_p;

  output reg Init_Done;
  output camera_rst_n;
  output camera_pwdn;

  output i2c_sclk;
  inout i2c_sdat;
  
  wire [15:0]addr;
  reg wrreg_req;
  reg rdreg_req;
  wire [7:0] wrdata;
  wire [7:0]rddata;
  wire RW_Done;
  wire ack;

  reg [7:0]cnt;
  wire [23:0]lut;

  wire [7:0]lut_size;
  wire [7:0] device_id;
  wire addr_mode;
  
  assign camera_pwdn = 0;
  
  assign device_id = 8'h78;
  assign addr_mode = 1'b1;
  assign addr = lut[23:8];
  assign wrdata = lut[7:0];
  assign lut_size = 252;

 
    ov5640_init_table_rgb #(
        .IMAGE_WIDTH        (IMAGE_WIDTH),
        .IMAGE_HEIGHT       (IMAGE_HEIGHT),
        .IMAGE_FLIP_EN      (IMAGE_FLIP_EN),
        .IMAGE_MIRROR_EN    (IMAGE_MIRROR_EN)
     )ov5640_init_table_rgb_inst
    (
        .addr (cnt ),
        .clk  (Clk ),
        .q    (lut )
    );
 
  i2c_control i2c_control(
    .Clk       (Clk       ),
    .Rst_p     (Rst_p     ),
    .wrreg_req (wrreg_req ),
    .rdreg_req (0         ),
    .addr      (addr      ),
    .addr_mode (addr_mode ),
    .wrdata    (wrdata    ),
    .rddata    (rddata    ),
    .device_id (device_id ),
    .RW_Done   (RW_Done   ),
    .ack       (ack       ),
    .i2c_sclk  (i2c_sclk  ),
    .i2c_sdat  (i2c_sdat  )
  );

  wire Go;   //initial enable
  reg [20:0] delay_cnt;

  //�ϵ粢��λ���20ms������������ͷ�����Դ��ϵ絽��ʼ����Ӧ����1.0034 + 20 = 21.0034ms
  //����Ϊ���Ż��߼����򻯱Ƚ����߼���ֱ��ʹ�ӳٱȽ�ֵΪ24'h100800����21.0125ms 
  always @ (posedge Clk or posedge Rst_p)
  if (Rst_p)
    delay_cnt <= 21'd0;
  else if (delay_cnt == 21'h100800)
    delay_cnt <= 21'h100800;
  else
    delay_cnt <= delay_cnt + 1'd1;
    
  //����ʱʱ�䵽����ʼʹ�ܳ�ʼ��ģ���OV5640�ļĴ�������д��
  assign Go = (delay_cnt == 21'h1007ff) ? 1'b1 : 1'b0;
  
  //5640Ҫ���ϵ���临λ״̬��Ҫ����1ms�������ϵ����Ҫ1ms֮����ʹ���ͷ�����ͷ�ĸ�λ�ź�
  //����Ϊ���Ż��߼����򻯱Ƚ����߼���ֱ��ʹ�ӳٱȽ�ֵΪ24'hC400����1.003520ms
  assign camera_rst_n = (delay_cnt > 21'h00C400);
  
  //��ʱ5msϵͳ
  reg [18:0] delay5ms_cnt;
  wire       delay5ms_flag;
  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)
    delay5ms_cnt <= 0;
  else if(cnt == 1 && RW_Done && (!ack))
    delay5ms_cnt <= 1;
  else if(delay5ms_cnt > 0)
    delay5ms_cnt <= delay5ms_cnt + 1;
  assign delay5ms_flag = delay5ms_cnt[18];
  
  //����ϵͳ
  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)
    cnt <= 0;
  else if(Go) 
    cnt <= 0;
  else if(cnt == 1)begin
    if(delay5ms_flag)
      cnt <= 2;
    else
      cnt <= 1;
  end
  else if(cnt < lut_size && cnt != 1)begin
    if(RW_Done && (!ack))
      cnt <= cnt + 1'b1;
    else
      cnt <= cnt;
  end
  else
    cnt <= 0;
    
  //���ָʾ
  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)
    Init_Done <= 0;
  else if(Go) 
    Init_Done <= 0;
  else if(cnt == lut_size)
    Init_Done <= 1;

  //״̬���ж��Ƿ�д��
  reg [1:0] state;
  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)begin
    state <= 0;
    wrreg_req <= 1'b0;
  end
  else if(cnt < lut_size)begin
    case(state)
      0:
        if(Go)
          state <= 1;
        else
          state <= 0;
      1:
        begin
          wrreg_req <= 1'b1;
          state <= 2;
        end
      2:
        begin
          wrreg_req <= 1'b0;
          if(cnt == 1 && delay5ms_flag)
            state <= 1;
          else if(cnt != 1 && RW_Done)
            state <= 1;
          else
            state <= 2;
        end
      default:state <= 0;
    endcase
  end
  else
    state <= 0;
endmodule