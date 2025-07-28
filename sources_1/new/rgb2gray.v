`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/03/24 17:15:52
// Design Name: RGB888-to-Gray module using 2 methods
// Module Name: rgb2gray
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 使用两种方法（平均值法、加权平均法）实现了RGB彩色图像灰度化处理
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 使用generate-if语句实现了两种方法的选择
// 平均值法：gray = (r + g + b) / 3 = (r + g + b) / 3 * (3 / 256) * (256 / 3) = (r + g + b) * 85 / 256 = (r + g + b) * 85 >> 8
// 加权平均法：gray = 0.299 * r + 0.587 * g + 0.114 * b = (77 * r + 150 * g + 29 * b) / 256 = (77 * r + 150 * g + 29 * b) >> 8
// 乘法均可转化为移位运算
//////////////////////////////////////////////////////////////////////////////////


module rgb2gray #(
    parameter METHOD = "WEIGHT"             // "AVERAGE": 平均值法，"WEIGHT": 加权平均法
    )(
    input           clk, rst_p,             // 时钟、复位信号
    input           rgb_valid,              // 输入RGB信号有效标志
    input           rgb_hsync, rgb_vsync,   // 输入RGB信号的行同步、场同步信号
    input   [7:0]   r, g, b,                // 输入三通道RGB888信号
    output  [7:0]   gray,                   // 输出灰度信号
    output  reg     gray_valid,             // 输出灰度信号有效标志
    output  reg     gray_hsync, gray_vsync  // 输出灰度信号的行同步、场同步信号
    );
    generate
        if (METHOD == "AVERAGE") begin: AVERAGE
            wire [9:0] sum;         // 存储三通道RGB信号的和
            reg [15:0] gray_tmp;    // 存储灰度信号的临时变量，注意计算最小位宽

            assign sum = r + g + b; // 计算三通道RGB信号的和

            always @(posedge clk or posedge rst_p)
                if (rst_p) 
                    gray_tmp <= 16'd0;
                else if (rgb_valid)
                    gray_tmp <= (sum << 6) + (sum << 4) + (sum << 2) + sum; // 这里实现了gray_tmp = (r + g + b) * 85，将乘法转化为移位运算
                else
                    gray_tmp <= 16'd0;

            assign gray = gray_tmp[15:8];   // 取高8位作为灰度信号，实现了gray = (r + g + b) * 85 >> 8
            always @(posedge clk) begin
                gray_valid <= rgb_valid;  // 灰度信号有效标志与RGB信号有效标志相同，经过寄存器同步输出
                gray_hsync <= rgb_hsync;  // 行同步信号同步输出
                gray_vsync <= rgb_vsync;  // 场同步信号同步输出
            end
        end
        else if (METHOD == "WEIGHT") begin: WEIGHT
            wire [15:0] red_x77, green_x150, blue_x29; // 存储三通道RGB信号乘以权重的结果
            reg [15:0] gray_tmp;    // 存储灰度信号的临时变量，注意计算最小位宽

            assign red_x77 = (r << 6) + (r << 3) + (r << 2) + r; // 计算红色通道乘以权重77的结果
            assign green_x150 = (g << 7) + (g << 4) + (g << 2) + (g << 1); // 计算绿色通道乘以权重150的结果
            assign blue_x29 = (b << 4) + (b << 3) + (b << 2) + b; // 计算蓝色通道乘以权重29的结果
            // 此处必须加括号，因为移位运算的优先级低于加法运算（由Simulation纠错）

            always @(posedge clk or posedge rst_p) begin
                if (rst_p) 
                    gray_tmp <= 16'd0;
                else if (rgb_valid)
                    gray_tmp <= red_x77 + green_x150 + blue_x29; // 实现了gray_tmp = 77 * r + 150 * g + 29 * b
                else
                    gray_tmp <= 16'd0;
            end

            assign gray = gray_tmp[15:8];   // 取高8位作为灰度信号，实现了gray = (77 * r + 150 * g + 29 * b) >> 8
            
            always @(posedge clk) begin
                gray_valid <= rgb_valid;  // 灰度信号有效标志与RGB信号有效标志相同，经过寄存器同步输出
                gray_hsync <= rgb_hsync;  // 行同步信号同步输出
                gray_vsync <= rgb_vsync;  // 场同步信号同步输出
            end
        end
        else begin: None
            assign gray = 8'hff;

            always @(posedge clk) begin
                gray_valid <= rgb_valid;  // 灰度信号有效标志无效
                gray_hsync <= rgb_hsync;  // 行同步信号无效
                gray_vsync <= rgb_vsync;  // 场同步信号无效
            end
        end
    endgenerate

endmodule
