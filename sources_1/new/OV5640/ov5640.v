module ov5640 #(
	parameter IMAGE_WIDTH  = 1280,	// 图像宽度
	parameter IMAGE_HEIGHT = 720	// 图像长度
	)(
	// Clock & Reset
	input clk_50m,				// 用于IIC初始化的50MHz时钟
	input clk_24m,				// 用于摄像头驱动的24MHz时钟
	input reset_p,              // 复位信号输入
	// Camera 1 Interface
	inout camera1_sdat,			// IIC数据
	input camera1_vsync,
	input camera1_href,
	input camera1_pclk,			// Resolution: 1280x720，像素时钟为74.25MHz，由OV5640提供
	input [7:0] camera1_data,	// OV5640输入数据

	output camera1_xclk,		// 摄像头驱动时钟
	output camera1_sclk,		// IIC时钟
	output camera1_rst_n,		// 摄像头复位
	output [7:0] red_8b,		// rgb888_red
	output [7:0] green_8b,		// rgb888_green
	output [7:0] blue_8b,		// rgb888_blue
	output image1_data_valid,	// 数据有效信号
	output image1_data_hs,		// 行同步信号
	output image1_data_vs		// 帧同步信号
	);

	//* Internal Connect
	wire g_rst_p;				// Reset
	wire camera1_init_done;
	wire pclk1_bufg_o;
	wire [15:0] image1_data;	// Camera 1 Interface
	
	assign camera1_xclk = clk_24m;
	
	camera_init #(
		.IMAGE_WIDTH 	(IMAGE_WIDTH/2),	// 图片宽度
		.IMAGE_HEIGHT	(IMAGE_HEIGHT),		// 图片高度
		.IMAGE_FLIP_EN  (0),				// 0: 不翻转，1: 上下翻转
		.IMAGE_MIRROR_EN(0) 				// 0: 不镜像，1: 左右镜像
	) camera1_init(
		.Clk         	(clk_50m),
		.Rst_p       	(reset_p),
		.Init_Done   	(camera1_init_done),
		.camera_rst_n	(camera1_rst_n),
		.camera_pwdn 	(),
		.i2c_sclk    	(camera1_sclk),
		.i2c_sdat    	(camera1_sdat)
	);
	
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

		.ImageState (),
		.DataValid  (image1_data_valid),	// output
		.DataPixel  (image1_data),			// output    [15:0]
		.DataHs     (image1_data_hs),		// output
		.DataVs     (image1_data_vs_reg),	// output
		.Xaddr      (),						// output    [11:0]
		.Yaddr      () 						// output    [11:0]
	);

	assign image1_data_vs = !image1_data_vs_reg;  	//* 这里取反以适应后续图像滤波的逻辑

	assign red_8b = {image1_data[15:11], 3'b000};	// rgb565 -> rgb888
	assign green_8b = {image1_data[10:5], 2'b00};	// rgb565 -> rgb888
	assign blue_8b = {image1_data[4:0], 3'b000};	// rgb565 -> rgb888
	//? 这部分转换模块可能是错误的
	//? One possible algorithm: R8 = ( R5 * 527 + 23 ) >> 6;
	//?						    G8 = ( G6 * 259 + 33 ) >> 6;
	//?						    B8 = ( B5 * 527 + 23 ) >> 6;
endmodule
