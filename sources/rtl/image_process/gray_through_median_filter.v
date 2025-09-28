`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/03/30 16:47:18
// Design Name: Gray-to-Median Filter module
// Module Name: gray_through_median_filter
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 将rgb2gray.v模块的输出八位灰度图像信号送入中值滤波器进行处理
// 
// Dependencies: shift_register_2taps.v, sort.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 灰度八位数据是从图像右上角第一行的单个像素开始串行发送的（八位数据本身并行发送）
// 本质上，该模块是实现了三维移位寄存器
//////////////////////////////////////////////////////////////////////////////////


module gray_through_median_filter #(
    parameter DATA_WIDTH = 8            // 数据位宽，即灰度数据的单个颜色通道的位宽
    )(
    input clk,                          // 时钟信号
    input rst_p,                        // 复位信号
    input gray_valid,                   // 输入灰度信号有效信号
    input gray_hsync,                   // 输入灰度信号行同步信号
    input gray_vsync,                   // 输入灰度信号场同步信号
    input [DATA_WIDTH-1:0] gray,        // 输入灰度信号

    output reg median_valid,
    output reg median_hsync,
    output reg median_vsync,            // 输出控制信号
    output [DATA_WIDTH-1:0] median_out  // 输出经过中值滤波后的8位灰度信号
    );

    //-----------------------------------------------------
    /*========缓存三行数据========*/
    //-----------------------------------------------------
    wire [7:0] line_0_data, line_1_data, line_2_data; // 存储三行数据，2为当前行，1为上一行，0为上上行

    assign line_2_data = gray; // 当前行数据

    shift_register_2taps #(
        .DATA_WIDTH     (DATA_WIDTH)
    ) shift_reg_2taps_inst(
        .clk            (clk),
        .dat_in         (gray),
        .dat_in_valid   (gray_valid),
        .dat_out        (),
        .taps1x         (line_1_data),  // 先输出的上一行数据
        .taps0x         (line_0_data)   // 后输出的上上行数据
    );
    // 这个模块似乎不需要同步，不占用时钟周期

    //-----------------------------------------------------
    /*========实现滑移KERNEL========*/
    //-----------------------------------------------------

    /******************************************************
    matrix 3*3*8
    | row0_col0, row0_col1, row0_col2 | <<<<<<< line_0_data (older)
    | row1_col0, row1_col1, row1_col2 | <<<<<<< line_1_data (old)
    | row2_col0, row2_col1, row2_col2 | <<<<<<< line_2_data (newest)
    *******************************************************/
    reg [7:0] row0_col0, row0_col1, row0_col2; // 上上行数据
    reg [7:0] row1_col0, row1_col1, row1_col2; // 上一行数据
    reg [7:0] row2_col0, row2_col1, row2_col2; // 当前行数据

    always @(posedge clk or posedge rst_p) begin
        if (rst_p) begin
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
        else if (gray_hsync && gray_vsync) begin
            if (gray_valid) begin           // 行同步和场同步信号有效且数据有效时，更新行数据
                row0_col2 <= line_0_data;   // 上上行数据
                row0_col1 <= row0_col2;
                row0_col0 <= row0_col1;

                row1_col2 <= line_1_data;   // 上一行数据
                row1_col1 <= row1_col2;
                row1_col0 <= row1_col1;

                row2_col2 <= line_2_data;   // 当前行数据
                row2_col1 <= row2_col2;
                row2_col0 <= row2_col1;
            end //数据无效时寄存
        end
        else begin  // 行同步和场同步无效时滑移核清零
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

    //-----------------------------------------------------
    /*========3*3像素矩阵排序========*/
    //-----------------------------------------------------

    // 同步控制信号
    reg [2:0] gray_valid_reg, gray_vsync_reg, gray_hsync_reg;   // 用于寄存行同步、场同步和数据有效信号
    always @(posedge clk) begin
        if (rst_p) begin
            gray_valid_reg <= {gray_valid_reg[1:0], 1'b0};          // 寄存数据有效信号，当复位时控制信号无效
            gray_hsync_reg <= {gray_hsync_reg[1:0], 1'b0};          // 寄存行同步信号
            gray_vsync_reg <= {gray_vsync_reg[1:0], 1'b0};          // 寄存场同步信号
        end
        else begin
            gray_valid_reg <= {gray_valid_reg[1:0], gray_valid};    // 寄存数据有效信号
            gray_hsync_reg <= {gray_hsync_reg[1:0], gray_hsync};    // 寄存行同步信号
            gray_vsync_reg <= {gray_vsync_reg[1:0], gray_vsync};    // 寄存场同步信号
        end
    end

    // 对line0第一行排序
    wire [DATA_WIDTH-1:0] line0_max, line0_mid, line0_min; // 存储line0排序结果
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_line0 (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[0]), // 数据有效信号，延时一拍以同步kernel
        .data0          (row0_col0),         // 输入数据
        .data1          (row0_col1),         // 输入数据
        .data2          (row0_col2),         // 输入数据
        .data_out_valid (),                  // 输出数据有效信号
        .data_max       (line0_max),         // 输出数据最大值
        .data_min       (line0_min),         // 输出数据最小值
        .data_mid       (line0_mid)          // 输出数据中间值
    );

    // 对line1第二行排序
    wire [DATA_WIDTH-1:0] line1_max, line1_mid, line1_min; // 存储line1排序结果
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_line1 (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[0]), // 数据有效信号，延时一拍以同步kernel
        .data0          (row1_col0),         // 输入数据
        .data1          (row1_col1),         // 输入数据
        .data2          (row1_col2),         // 输入数据
        .data_out_valid (),                  // 输出数据有效信号
        .data_max       (line1_max),         // 输出数据最大值
        .data_min       (line1_min),         // 输出数据最小值
        .data_mid       (line1_mid)          // 输出数据中间值
    );

    // 对line2第三行排序
    wire [DATA_WIDTH-1:0] line2_max, line2_mid, line2_min; // 存储line2排序结果
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_line2 (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[0]), // 数据有效信号，延时一拍以同步kernel
        .data0          (row2_col0),         // 输入数据
        .data1          (row2_col1),         // 输入数据
        .data2          (row2_col2),         // 输入数据
        .data_out_valid (),                  // 输出数据有效信号
        .data_max       (line2_max),         // 输出数据最大值
        .data_min       (line2_min),         // 输出数据最小值
        .data_mid       (line2_mid)          // 输出数据中间值
    );

    /*********************************************
    排序后结果：
    | line0_max, line0_mid, line0_min |
    | line1_max, line1_mid, line1_min |
    | line2_max, line2_mid, line2_min |
    *********************************************/

    // 对第一列进行排序，即三行的最大值进行排序
    wire [DATA_WIDTH-1:0] max_max, max_mid, max_min; // 存储第一列排序结果
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_max (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[1]), // 数据有效信号，延时两拍以同步kernel
        .data0          (line0_max),         // 输入数据
        .data1          (line1_max),         // 输入数据
        .data2          (line2_max),         // 输入数据
        .data_out_valid (),                  // 输出数据有效信号
        .data_max       (max_max),           // 输出数据最大值
        .data_min       (max_min),           // 输出数据最小值
        .data_mid       (max_mid)            // 输出数据中间值
    );

    // 对第二列进行排序，即三行的中间值进行排序
    wire [DATA_WIDTH-1:0] mid_max, mid_mid, mid_min; // 存储第二列排序结果
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_mid (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[1]), // 数据有效信号，延时两拍以同步kernel
        .data0          (line0_mid),         // 输入数据
        .data1          (line1_mid),         // 输入数据
        .data2          (line2_mid),         // 输入数据
        .data_out_valid (),                  // 输出数据有效信号
        .data_max       (mid_max),           // 输出数据最大值
        .data_min       (mid_min),           // 输出数据最小值
        .data_mid       (mid_mid)            // 输出数据中间值
    );

    // 对第三列进行排序，即三行的最小值进行排序
    wire [DATA_WIDTH-1:0] min_max, min_mid, min_min; // 存储第三列排序结果
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_min (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[1]), // 数据有效信号，延时两拍以同步kernel
        .data0          (line0_min),         // 输入数据
        .data1          (line1_min),         // 输入数据
        .data2          (line2_min),         // 输入数据
        .data_out_valid (),                  // 输出数据有效信号
        .data_max       (min_max),           // 输出数据最大值
        .data_min       (min_min),           // 输出数据最小值
        .data_mid       (min_mid)            // 输出数据中间值
    );

    /************************************
    排序后结果（注意将矩阵转置了）：
    | max_max, max_mid, max_min |
    | mid_max, mid_mid, mid_min |
    | min_max, min_mid, min_min |
    *************************************/

    // 对斜对角线进行排序，即三行最大值的最小值、三行最小值的最大值、三行中间值的中间值进行排序
    wire [DATA_WIDTH-1:0] median_out_tmp;        // 存储中值滤波器输出的中间值
    sort #(
        .DATA_WIDTH (DATA_WIDTH)
    ) sort_median (
        .clk            (clk),
        .rst_p          (rst_p),
        .data_in_valid  (gray_valid_reg[2]),    // 数据有效信号，延时三拍以同步kernel
        .data0          (max_min),              // 输入数据
        .data1          (mid_mid),              // 输入数据
        .data2          (min_max),              // 输入数据
        .data_out_valid (),                     // 输出数据有效信号
        .data_max       (),                     // 输出数据最大值
        .data_min       (),                     // 输出数据最小值
        .data_mid       (median_out_tmp)        // 输出数据中间值
    );

    // 输出中值滤波器的结果，注意控制信号还要再延时一拍
    assign median_out = median_out_tmp;         // 输出中值滤波器的输出
    always @(posedge clk) begin
        median_valid <= gray_valid_reg[2];      // 输出数据有效信号，共延时四拍以同步kernel
        median_hsync <= gray_hsync_reg[2];      // 输出行同步信号，共延时四拍以同步kernel
        median_vsync <= gray_vsync_reg[2];      // 输出场同步信号，共延时四拍以同步kernel
    end

    // 只要某一级寄存器用到上一级寄存器的输出，便意味着延时一个时钟周期
endmodule
