module ov5640 #(
	parameter IMAGE_WIDTH  = 1280,	// ͼ�����
	parameter IMAGE_HEIGHT = 720	// ͼ�񳤶�
	)(
	// Clock & Reset
	input clk_50m,				// ����IIC��ʼ����50MHzʱ��
	input clk_24m,				// ��������ͷ������24MHzʱ��
	input reset_p,              // ��λ�ź�����
	// Camera 1 Interface
	inout camera1_sdat,			// IIC����
	input camera1_vsync,
	input camera1_href,
	input camera1_pclk,			// Resolution: 1280x720������ʱ��Ϊ74.25MHz����OV5640�ṩ
	input [7:0] camera1_data,	// OV5640��������

	output camera1_xclk,		// ����ͷ����ʱ��
	output camera1_sclk,		// IICʱ��
	output camera1_rst_n,		// ����ͷ��λ
	output [7:0] red_8b,		// rgb888_red
	output [7:0] green_8b,		// rgb888_green
	output [7:0] blue_8b,		// rgb888_blue
	output image1_data_valid,	// ������Ч�ź�
	output image1_data_hs,		// ��ͬ���ź�
	output image1_data_vs		// ֡ͬ���ź�
	);

	//* Internal Connect
	wire g_rst_p;				// Reset
	wire camera1_init_done;
	wire pclk1_bufg_o;
	wire [15:0] image1_data;	// Camera 1 Interface
	
	assign camera1_xclk = clk_24m;
	
	camera_init #(
		.IMAGE_WIDTH 	(IMAGE_WIDTH/2),	// ͼƬ����
		.IMAGE_HEIGHT	(IMAGE_HEIGHT),		// ͼƬ�߶�
		.IMAGE_FLIP_EN  (0),				// 0: ����ת��1: ���·�ת
		.IMAGE_MIRROR_EN(0) 				// 0: ������1: ���Ҿ���
	) camera1_init(
		.Clk         	(clk_50m),
		.Rst_p       	(reset_p),
		.Init_Done   	(camera1_init_done),
		.camera_rst_n	(camera1_rst_n),
		.camera_pwdn 	(),
		.i2c_sclk    	(camera1_sclk),
		.i2c_sdat    	(camera1_sdat)
	);
	
	//TODO: Implementation显示BUFG与IO靠得过近，因此报错，可考虑忽略报错（修改约束文件）或删除BUFG
	BUFG BUFG_inst1 (
		.O	(pclk1_bufg_o), 	// 1-bit output: Clock output
		.I	(camera1_pclk)  	// 1-bit input: Clock input
	);
	
	wire image1_data_vs_reg;

	DVP_Capture DVP_Capture_inst1(
		.Rst_p      (reset_p),				// input
		.PCLK       (pclk1_bufg_o),			// input
		.Vsync      (camera1_vsync),		// input
		.Href       (camera1_href),			// input
		.Data       (camera1_data),			// input     [7:0]

		.DataValid  (image1_data_valid),	// output
		.DataPixel  (image1_data),			// output    [15:0]
		.DataHs     (image1_data_hs),		// output
		.DataVs     (image1_data_vs_reg),	// output
		.Xaddr      (),						// output    [11:0]
		.Yaddr      () 						// output    [11:0]
	);

	assign image1_data_vs = !image1_data_vs_reg;  	//* ����ȡ������Ӧ����ͼ���˲����߼�

	assign red_8b = {image1_data[15:11], 3'b000};	// rgb565 -> rgb888
	assign green_8b = {image1_data[10:5], 2'b00};	// rgb565 -> rgb888
	assign blue_8b = {image1_data[4:0], 3'b000};	// rgb565 -> rgb888
	//? �ⲿ��ת��ģ������Ǵ����
	//? One possible algorithm: R8 = ( R5 * 527 + 23 ) >> 6;
	//?						    G8 = ( G6 * 259 + 33 ) >> 6;
	//?						    B8 = ( B5 * 527 + 23 ) >> 6;
endmodule
