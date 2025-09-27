`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/08/27 17:43:32
// Design Name: Image Process Top Module
// Module Name: ImageProcess
// Project Name: ImageProcess
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 图像处理顶层模块，负责整个图像处理流程的控制和数据流转
// 
// Dependencies: ov5640.v, image_process_top.v, ethernet.v & clock module.
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 1. 系统复位信号rst_n约束至开发板S4按键
// 2. PHY配置完成标志phy_config_done约束至开发板LED0（目前PHY配置模块未启用，因此配置完成标志始终无效）
//////////////////////////////////////////////////////////////////////////////////


module ImageProcess #(
    // Image Filter Parameters
    parameter IMAGE_WIDTH = 1280,       // 图像宽度，单位：像素
    parameter IMAGE_HEIGHT = 720,       // 图像高度，单位：像素
    parameter DATA_WIDTH = 8,           // 灰度滤波后图像的位宽
    parameter THRESHOLD = 8'd128,       // SOBEL算子阈值
    parameter METHOD = "WEIGHT",        // 灰度滤波办法，"AVERAGE": 平均值法，"WEIGHT": 加权平均法
    // Ethernet Parameters
    parameter [1:0] ETHERNET_SPEED = 2'b10,             // 10为千兆，01为百兆，00为十兆
    parameter [47:0] DES_MAC = 48'hff_ff_ff_ff_ff_ff,   // 目标MAC地址，默认为广播地址
    parameter [47:0] SRC_MAC = 48'h00_0a_35_01_fe_c0,   // 源MAC地址，需在实例化时指定
    parameter [31:0] DES_IP = 32'hc0_a8_00_03,          // 目标IP地址，默认为192.168.0.3
    parameter [31:0] SRC_IP = 32'hc0_a8_00_02,          // 源IP地址，默认为192.168.0.2
    parameter [15:0] DES_UDP_PORT = 16'd6102,           // 目标UDP端口号，默认为6102
    parameter [15:0] SRC_UDP_PORT = 16'd5000,           // 源UDP端口号，默认为5000
    parameter [15:0] DATA_LENGTH = IMAGE_WIDTH / 8 + 2  // 用户单帧数据长度（不包含任何报头）
    )(
    input clk_sys,              // 系统50MHz晶振时钟
    input clk_pixel,            // 由OV5640提供的像素时钟
    input rst_n,                // 系统复位信号，低电平有效
    // OV5640 Camera Interface
    inout camera_sdat,			// IIC数据
	input camera_vsync,         // 场同步信号
	input camera_href,          // 行同步信号
	input [7:0] camera_data,	// OV5640输入数据

    output camera_xclk,		    // 摄像头驱动时钟
	output camera_sclk,		    // IIC时钟
	output camera_rst_n,		// 摄像头复位
    // Ethernet
    output [3:0] rgmii_txd,     // RGMII发送数据线
    output rgmii_tx_clk,        // RGMII发送时钟
    output rgmii_tx_ctl,        // RGMII发送控制信号
    output phy_config_done,     // PHY配置完成标志
    output mdc,                 // MDC时钟信号
    inout mdio                  // MDIO数据线
    );

    //* 1. Clock Generation
    wire clk_125m;              // 125MHz以太网发送时钟
    wire clk_50m;               // 50MHz时钟
    wire clk_24m;               // 24MHz时钟
    wire locked;                // 锁相环标志

    clk_wiz_sys clk_wiz_sys(
    // Clock out ports
    .clk_125m   (clk_125m),     // output clk_125m
    .clk_50m    (clk_50m),      // output clk_50m
    .clk_24m    (clk_24m),      // output clk_24m
    // Status and control signals
    .reset      (!rst_n),       // input reset
    .locked     (locked),       // output locked
    // Clock in ports
    .clk_sys    (clk_sys)       // input clk_sys
    );

    //* 2. OV5640 Module Instantiation
    wire [7:0] red;     // OV5640输出8 bit红色像素数据
    wire [7:0] green;   // OV5640输出8 bit绿色像素数据
    wire [7:0] blue;    // OV5640输出8 bit蓝色像素数据
    wire rgb_valid;     // OV5640输出RGB有效信号
    wire rgb_hsync;     // OV5640输出RGB行同步信号
    wire rgb_vsync;     // OV5640输出RGB场同步信号

    ov5640 #(
        .IMAGE_WIDTH    (IMAGE_WIDTH),    // 图像宽度
        .IMAGE_HEIGHT   (IMAGE_HEIGHT)    // 图像高度
    ) ov5640(
        // inputs
        .clk_50m            (clk_50m),
        .clk_24m            (clk_24m),
        .reset_p            (!rst_n),
        .camera1_sdat       (camera_sdat),
        .camera1_vsync      (camera_vsync),
        .camera1_href       (camera_href),
        .camera1_pclk       (clk_pixel),
        .camera1_data       (camera_data),
        // outputs
        .camera1_xclk       (camera_xclk),
        .camera1_sclk       (camera_sclk),
        .camera1_rst_n      (camera_rst_n),
        .red_8b             (red),
        .green_8b           (green),
        .blue_8b            (blue),
        .image1_data_valid  (rgb_valid),
        .image1_data_hs     (rgb_hsync),
        .image1_data_vs     (rgb_vsync)
    );

    //* 3. Image Filter Module Instantiation
    wire sobel;
    wire sobel_valid;
    wire sobel_hsync;
    wire sobel_vsync;
    reg clk_pixel_division;             // 二分频像素时钟

    always @(posedge clk_pixel)
        clk_pixel_division <= ~clk_pixel_division;
    //! 这一部分的时钟产生很可能不可用

    image_process_top #(
        .DATA_WIDTH     (DATA_WIDTH),   // 数据位宽，即灰度数据的单个颜色通道的位宽
        .THRESHOLD      (THRESHOLD),    // SOBEL算子阈值
        .METHOD         (METHOD)        // 灰度滤波办法，"AVERAGE": 平均值法，"WEIGHT": 加权平均法
    ) image_process_top(
        // inputs
        .clk            (clk_pixel_division),       // 像素时钟，二分频
        .rst_p          (!rst_n),                   // 复位信号，高电平有效
        .rgb_valid      (rgb_valid),                // 输入RGB信号有效标志
        .rgb_hsync      (rgb_hsync),                // 输入RGB信号的行同步信号
        .rgb_vsync      (rgb_vsync),                // 输入RGB信号的场同步信号
        .r              (red),                      // 输入8 bit红色像素数据
        .g              (green),                    // 输入8 bit绿色像素数据
        .b              (blue),                     // 输入8 bit蓝色像素数据
        // outputs
        .sobel          (sobel),                    // 输出经过SOBEL算子处理后的图像数据
        .sobel_valid    (sobel_valid),              // 输出经过SOBEL算子处理后的图像数据有效标志
        .sobel_hsync    (sobel_hsync),              // 输出经过SOBEL算子处理后的图像数据行同步信号
        .sobel_vsync    (sobel_vsync)               // 输出经过SOBEL算子处理后的图像数据场同步信号
    );

    //* 4. Ethernet Transmit Module Instantiation
    ethernet #(
        .IMAGE_WIDTH    (IMAGE_WIDTH),
        .IMAGE_HEIGHT   (IMAGE_HEIGHT),
        .ETHERNET_SPEED (ETHERNET_SPEED),
        .DES_MAC        (DES_MAC),
        .SRC_MAC        (SRC_MAC),
        .DES_IP         (DES_IP),
        .SRC_IP         (SRC_IP),
        .DES_UDP_PORT   (DES_UDP_PORT),
        .SRC_UDP_PORT   (SRC_UDP_PORT),
        .DATA_LENGTH    (DATA_LENGTH)
    ) ethernet(
        // inputs
        .clk_pixel      (clk_pixel_division),   // 像素时钟，二分频
        .clk_eth        (clk_125m),             // 以太网发送125MHz时钟
        .clk_phy        (clk_50m),              // PHY配置时钟，50MHz
        .rst_n          (rst_n),                // 复位信号，低电平有效
        .valid          (sobel_valid),
        .hsync          (sobel_hsync),
        .vsync          (sobel_vsync),
        .sobel          (sobel),
        // outputs
        .rgmii_txd      (rgmii_txd),
        .rgmii_tx_clk   (rgmii_tx_clk),
        .rgmii_tx_ctl   (rgmii_tx_ctl),
        .phy_config_done(phy_config_done),      // PHY配置完成标志
        .phy_read_data  (),                     // 读到的PHY数据，暂时未接
        .mdc            (mdc),
        .mdio           (mdio)
    );
endmodule
