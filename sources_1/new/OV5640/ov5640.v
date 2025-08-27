module ov5640(
  //System clock reset
  input           clk50m        , //ϵͳ����ʱ�����룬50MHz
  input           reset_p       , //��λ�ź�����
  //camera1 interface
  inout           camera1_sdat  ,//i2c����
  input           camera1_vsync ,
  input           camera1_href  ,
  input           camera1_pclk  ,//Resolution_1280x720  ����ʱ��Ϊ74.25MHz
  input  [7:0]    camera1_data  ,//ov5640��������
  
  output          camera1_xclk  ,//����ͷ����ʱ��
  output          camera1_sclk  ,//i2cʱ��
  output          camera1_rst_n  ,//����ͷ��λ
  output [7:0]    red_8b_i      ,//rgb888_red
  output [7:0]    green_8b_i      ,//rgb888_green
  output [7:0]    blue_8b_i      ,//rgb888_blue
  output          image1_data_valid ,//���ƻҶȴ���ʼ�ź�
  output          image1_data_hs ,//��ͬ���ź�
  output          image1_data_vs//֡ͬ���ź�
    );
  parameter DISP_WIDTH  = 1280;
  parameter DISP_HEIGHT = 720;
//*********************************
//Internal connect
//*********************************
  //clock
  wire          pll_locked;
  wire          loc_clk50m;
  wire          loc_clk24m;

  //reset
  wire          g_rst_p;
  //camera1 interface
  wire          camera1_init_done;
  wire          pclk1_bufg_o;
  wire [15:0]   image1_data;

  clk_wiz_0 clk_wiz_0
  (
    // Clock out ports
    .clk_out1 (loc_clk50m   ), // output clk_out1
    .clk_out2 (loc_clk24m   ), // output clk_out2
    // Status and control signals
    .reset   (reset_p      ), // input reset
    .locked   (pll_locked   ), // output locked
    // Clock in ports
    .clk_in1  (clk50m       )  // input clk_in1
  );
  
  assign camera1_xclk = loc_clk24m;
  
  camera_init
  #(
    .IMAGE_WIDTH ( DISP_WIDTH/2 ),// ͼƬ���
    .IMAGE_HEIGHT( DISP_HEIGHT  ),// ͼƬ�߶�
    .IMAGE_FLIP_EN  ( 0            ),// 0: ����ת��1: ���·�ת
    .IMAGE_MIRROR_EN( 0            ) // 0: ������1: ���Ҿ���
  )camera1_init
  (
    .Clk         (loc_clk50m        ),
    .Rst_p       (reset_p           ),
    .Init_Done   (camera1_init_done ),
    .camera_rst_n(camera1_rst_n     ),
    .camera_pwdn (                  ),
    .i2c_sclk    (camera1_sclk      ),
    .i2c_sdat    (camera1_sdat      )
  );
  
  BUFG BUFG_inst1 (
    .O(pclk1_bufg_o ), // 1-bit output: Clock output
    .I(camera1_pclk )  // 1-bit input: Clock input
  );
  
  wire image1_data_vs_reg;

  DVP_Capture DVP_Capture_inst1(
    .Rst_p      (reset_p          ),//input
    .PCLK       (pclk1_bufg_o      ),//input
    .Vsync      (camera1_vsync     ),//input
    .Href       (camera1_href      ),//input
    .Data       (camera1_data      ),//input     [7:0]

    .ImageState (),
    .DataValid  (image1_data_valid ),//output
    .DataPixel  (image1_data       ),//output    [15:0]
    .DataHs     (image1_data_hs    ),//output
    .DataVs     (image1_data_vs_reg),//output
    .Xaddr      (                  ),//output    [11:0]
    .Yaddr      (                  ) //output    [11:0]
  );
  assign image1_data_vs = !image1_data_vs_reg;  //! ����ȡ������Ӧ����ͼ���˲����߼�

  assign   red_8b_i = {image1_data[15:11],3'b000};//rgb565->rgb888
  assign   green_8b_i = {image1_data[10:5],2'b00};//rgb565->rgb888
  assign   blue_8b_i = {image1_data[4:0],3'b000};//rgb565->rgb888
  endmodule