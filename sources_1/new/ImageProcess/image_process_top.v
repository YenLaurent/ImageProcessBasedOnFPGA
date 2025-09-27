`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/04/04 17:03:54
// Design Name: Top module for image processing
// Module Name: image_process_top
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 图像预处理顶层模块，输入RGB888图像数据，经过灰度化处理、中值滤波处理、边缘检测处理后输出二值图像数据
// 
// Dependencies: rgb2gray.v, gray_through_median_filter.v, sobel.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//!1. 实际的vsync信号与本模块vsync逻辑是相反的，即场同步信号在发送完一帧图像后有效，在最终顶层模块例化时一定要特别注意将摄像头模块输出vsync信号取反
//!2. 该模块认为输入数据有效信号与hsync信号是同步的，即在行同步信号有效时，数据有效信号也是有效的，这或许需要后续对摄像头模块、图像预处理模块的信号进行调整
//!   最好是直接在摄像头模块的输出端加上缓冲器以控制数据输出，使得valid信号与hsync信号同步，不再有valid无效的情况，这样可以最大限度避免出错
//!   当然，这会不可避免地将图像处理模块的时钟再次拉低
//*3. 图像处理模块的像素时钟由OV5640直接提供，但由于逻辑设计，需要二分频后使用，即每两个像素时钟数据有效一次
//////////////////////////////////////////////////////////////////////////////////


module image_process_top #(
    parameter DATA_WIDTH = 8,           // 数据位宽，即灰度数据的单个颜色通道的位宽
    parameter THRESHOLD = 8'd50,        // sobel算子阈值
    parameter METHOD = "WEIGHT"         // 灰度滤波办法，"AVERAGE": 平均值法，"WEIGHT": 加权平均法
    )(
    input clk, rst_p,                   // 时钟、复位信号
    input rgb_valid,                    // 输入RGB信号有效标志
    input rgb_hsync, rgb_vsync,         // 输入RGB信号的行同步、场同步信号
    input [DATA_WIDTH-1:0] r, g, b,     // 输入三通道RGB888信号
    
    output sobel,                       // 输出经过sobel算子处理后的图像数据，为二值数据，只有黑和白
    output sobel_valid,                 // 输出数据有效信号
    output sobel_hsync, sobel_vsync     // 输出数据行同步、场同步信号
    );

    wire [DATA_WIDTH-1:0] gray;         // 灰度图像数据
    wire gray_valid;                    // 灰度图像数据有效信号
    wire gray_hsync, gray_vsync;        // 灰度图像数据行同步、场同步信号
    wire [DATA_WIDTH-1:0] median;       // 中值滤波后的灰度图像数据
    wire median_valid;                  // 中值滤波后的灰度图像数据有效信号
    wire median_hsync, median_vsync;    // 中值滤波后的灰度图像数据行同步、场同步信号

    rgb2gray #(
        .METHOD         (METHOD)        // 选择灰度化处理方法
    ) rgb2gray(
        .clk            (clk),
        .rst_p          (rst_p),
        .rgb_valid      (rgb_valid),
        .rgb_hsync      (rgb_hsync),
        .rgb_vsync      (rgb_vsync),
        .r              (r),
        .g              (g),
        .b              (b),
        .gray           (gray),         // 输出灰度信号
        .gray_valid     (gray_valid),   // 输出灰度信号有效标志
        .gray_hsync     (gray_hsync),   // 输出灰度信号的行同步、场同步信号
        .gray_vsync     (gray_vsync)
    );

    gray_through_median_filter #(
        .DATA_WIDTH     (DATA_WIDTH)    // 数据位宽，即灰度数据的单个颜色通道的位宽
    ) gray_through_median_filter(
        .clk            (clk),
        .rst_p          (rst_p),
        .gray           (gray),         // 输入经过中值滤波后的灰度图像数据
        .gray_valid     (gray_valid),   // 输入数据有效信号
        .gray_hsync     (gray_hsync),   // 输入数据行同步信号
        .gray_vsync     (gray_vsync),   // 输入数据场同步信号
        .median_out     (median),       // 输出经过中值滤波后的图像数据
        .median_valid   (median_valid), // 输出数据有效信号
        .median_hsync   (median_hsync), // 输出数据行同步信号 
        .median_vsync   (median_vsync)  // 输出数据场同步信号
    );

    sobel #(
        .DATA_WIDTH     (DATA_WIDTH),   // 数据位宽，即灰度数据的单个颜色通道的位宽
        .THRESHOLD      (THRESHOLD)     // sobel算子阈值
    ) sobel_inst(
        .clk            (clk),
        .reset_p        (rst_p),        // 时钟、复位信号
        .median         (median),       // 输入经过中值滤波后的灰度图像数据
        .median_valid   (median_valid), // 输入数据有效信号
        .median_hsync   (median_hsync), // 输入数据行同步信号
        .median_vsync   (median_vsync), // 输入数据场同步信号

        .sobel          (sobel),        // 输出经过sobel算子处理后的图像数据，为二值数据，只有黑和白
        .sobel_valid    (sobel_valid),  // 输出数据有效信号
        .sobel_hsync    (sobel_hsync),  // 输出数据行同步信号 
        .sobel_vsync    (sobel_vsync)   // 输出数据场同步信号
    );
endmodule
