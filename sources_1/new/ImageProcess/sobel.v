`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/03/31 17:15:56
// Design Name: Edge detection module using SOBEL
// Module Name: sobel
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 该模块将中值滤波后的8位灰度图像进行边缘检测处理，使用SOBEL算子对输入图像进行卷积，
// 输出结果为二值像素数据，黑色（0）表示关键边缘，白色（1）表示非关键边缘，
// 其判别逻辑为：卷积后的结果大于设定阈值则为黑色（0），小于阈值则为白色（1）
// Dependencies: shift_register_2taps.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 同样需要实现输入图像的3*3滑移窗口，与中值滤波类似
// 所采用SOBEL算子：
// Gx = [-1, 0, 1; 
//       -2, 0, 2; 
//       -1, 0, 1]
// Gy = [1, 2, 1; 
//       0, 0, 0; 
//       -1, -2, -1]
// G = sqrt(Gx^2 + Gy^2) ≈ |Gx| + |Gy|
//////////////////////////////////////////////////////////////////////////////////


module sobel #(
    parameter DATA_WIDTH = 8,           // 数据位宽，即灰度数据的单个颜色通道的位宽
    parameter THRESHOLD = 128           // SOBEL算子阈值
    )(
    input clk, reset_p,                 // 时钟、复位信号
    input [DATA_WIDTH-1:0] median,      // 输入经过中值滤波后的灰度图像数据
    input median_valid,                 // 输入数据有效信号
    input median_hsync,                 // 输入数据行同步信号
    input median_vsync,                 // 输入数据场同步信号

    output reg sobel,                   // 输出经过SOBEL算子处理后的图像数据，为二值数据，只有黑和白
    output reg sobel_valid,             // 输出数据有效信号
    output reg sobel_hsync,             // 输出数据行同步信号 
    output reg sobel_vsync              // 输出数据场同步信号
    );

    /*-------------------------------------------
    // 0. 信号声明
    -------------------------------------------*/
    // Line data
    wire [DATA_WIDTH-1:0] line0_data, line1_data, line2_data; // 存储三行图像数据，2为当前行，1为上一行，0为上上行
    // Matrix 3x3 window
    reg [DATA_WIDTH-1:0] row0_col0, row0_col1, row0_col2;  // <<----line0_data 上上行数据
    reg [DATA_WIDTH-1:0] row1_col0, row1_col1, row1_col2;  // <<----line1_data 上一行数据
    reg [DATA_WIDTH-1:0] row2_col0, row2_col1, row2_col2;  // <<----line2_data 当前行数据
    // Control signal's shift register
    (* dont_touch = "true" *) reg [2:0] median_valid_reg;
    (* dont_touch = "true" *) reg [2:0] median_hsync_reg;
    (* dont_touch = "true" *) reg [2:0] median_vsync_reg;
    // Convolution signal
    wire Gx_is_positive;    // Gx卷积结果正负，便于后续取绝对值操作
    wire Gy_is_positive;    // Gy卷积结果正负

    reg [DATA_WIDTH+1:0] Gx_absolute;   // Gx卷积结果绝对值
    reg [DATA_WIDTH+1:0] Gy_absolute;   // Gy卷积结果绝对值
    // 增大两位位宽是因为若是3*3滑移窗口恰好一行/列均为255最大值，一行恰好为0，则卷积结果为255*4=1020，因此需要增大两位位宽避免溢出

    /*-------------------------------------------
    // 1. 实现输入数据的滑移3*3窗口
    -------------------------------------------*/
    // 这部分与中值滤波模块完全一致
    assign line2_data = median; // 当前行数据

    // RAM移位寄存器存储两行像素数据
    shift_register_2taps #(
        .DATA_WIDTH     (DATA_WIDTH)
    ) shift_reg_2taps (
        .clk            (clk),
        .dat_in         (median),
        .dat_in_valid   (median_valid),
        .dat_out        (),   // 上上行数据
        .taps1x         (line1_data),   // 上一行数据
        .taps0x         (line0_data)    // 上上行数据
    );

    // 3*3窗口数据移位寄存器
    always @(posedge clk or posedge reset_p) begin
        if (reset_p) begin
            row0_col0 <= 'd0;
            row0_col1 <= 'd0;
            row0_col2 <= 'd0;

            row1_col0 <= 'd0;
            row1_col1 <= 'd0;
            row1_col2 <= 'd0;

            row2_col0 <= 'd0;
            row2_col1 <= 'd0;
            row2_col2 <= 'd0;
        end
        else if (median_vsync && median_hsync) begin
            if (median_valid) begin
                row0_col2 <= line0_data;    // 移位寄存器实现滑移窗口
                row0_col1 <= row0_col2;     // 上上行数据
                row0_col0 <= row0_col1;     // 上上行数据

                row1_col2 <= line1_data;    // 上一行数据
                row1_col1 <= row1_col2;     // 上一行数据
                row1_col0 <= row1_col1;     // 上一行数据

                row2_col2 <= line2_data;    // 当前行数据
                row2_col1 <= row2_col2;     // 当前行数据
                row2_col0 <= row2_col1;     // 当前行数据
            end
        end
        else begin
            row0_col0 <= 'd0;
            row0_col1 <= 'd0;
            row0_col2 <= 'd0;

            row1_col0 <= 'd0;
            row1_col1 <= 'd0;
            row1_col2 <= 'd0;

            row2_col0 <= 'd0;
            row2_col1 <= 'd0;
            row2_col2 <= 'd0;
        end
    end

    /*-------------------------------------------
    // 2. 输入数据的滑移3*3窗口与卷积核进行卷积
    -------------------------------------------*/
    // 控制信号流水线延迟
    always @(posedge clk) begin
        median_valid_reg <= {median_valid_reg[1:0], median_valid}; // 3位寄存器实现移位
        median_hsync_reg <= {median_hsync_reg[1:0], median_hsync}; // 3位寄存器实现移位
        median_vsync_reg <= {median_vsync_reg[1:0], median_vsync}; // 3位寄存器实现移位
    end

    // 卷积计算
    assign Gx_is_positive = (row0_col2 + row1_col2*2 + row2_col2) >= (row0_col0 + row1_col0*2 + row2_col0);
    assign Gy_is_positive = (row0_col0 + row0_col1*2 + row0_col2) >= (row2_col0 + row2_col1*2 + row2_col2); 
    // 判断不同方向上卷积结果的正负，便于后续取绝对值操作

    // Gx卷积结果
    always @(posedge clk or posedge reset_p) begin
        if (reset_p)    Gx_absolute <= 'd0;
        else if (median_valid_reg[0]) begin // 延时一个时钟周期
            if (Gx_is_positive) begin
                Gx_absolute <= (row0_col2 + row1_col2*2 + row2_col2) - (row0_col0 + row1_col0*2 + row2_col0);
            end
            else begin
                Gx_absolute <= (row0_col0 + row1_col0*2 + row2_col0) - (row0_col2 + row1_col2*2 + row2_col2);
            end
        end
    end

    // Gy卷积结果
    always @(posedge clk or posedge reset_p) begin
        if (reset_p)    Gy_absolute <= 'd0;
        else if (median_valid_reg[0]) begin // 延时一个时钟周期
            if (Gy_is_positive) begin
                Gy_absolute <= (row0_col0 + row0_col1*2 + row0_col2) - (row2_col0 + row2_col1*2 + row2_col2);
            end
            else begin
                Gy_absolute <= (row2_col0 + row2_col1*2 + row2_col2) - (row0_col0 + row0_col1*2 + row0_col2);
            end
        end
    end

    // 最终结果
    always @(posedge clk or posedge reset_p)
        if (reset_p)    sobel <= 1'b0;
        else if (median_valid_reg[1])   sobel <= ((Gx_absolute + Gy_absolute) > THRESHOLD) ? 1'b1 : 1'b0;
        // 延时两个时钟周期

    always @(posedge clk) begin
        sobel_valid <= median_valid_reg[1]; // 延时两个时钟周期
        sobel_hsync <= median_hsync_reg[1]; // 延时两个时钟周期
        sobel_vsync <= median_vsync_reg[1]; // 延时两个时钟周期
    end
endmodule
