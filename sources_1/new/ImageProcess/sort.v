`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/03/30 18:00:28
// Design Name: Sorting 
// Module Name: sort
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 该模块实现了三个8位数据的排序功能，用于中值滤波，后续只需调用模块配置不同输入便可实现3*3窗口的排序
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sort #(
    parameter DATA_WIDTH = 8                    // 数据位宽，即灰度数据的单个颜色通道的位宽
    )(
    input clk, rst_p,                           // 时钟、复位信号
    input data_in_valid,                        // 输入数据有效信号
    input [DATA_WIDTH-1:0] data0,               // 输入8位数据
    input [DATA_WIDTH-1:0] data1,               // 输入8位数据
    input [DATA_WIDTH-1:0] data2,               // 输入8位数据

    output reg data_out_valid,                  // 输出数据有效信号
    output reg [DATA_WIDTH-1:0] data_max,       // 输出数据最大值
    output reg [DATA_WIDTH-1:0] data_min,       // 输出数据最小值
    output reg [DATA_WIDTH-1:0] data_mid        // 输出数据中间值
    );

    always @(posedge clk or posedge rst_p) begin
        if (rst_p) begin
            data_max <= 'd0;
            data_min <= 'd0;
            data_mid <= 'd0;
        end
        else if (data_in_valid) begin
            if (data0 >= data1 && data0 >= data2) begin
                data_max <= data0;

                if (data1 >= data2) begin
                    data_mid <= data1;
                    data_min <= data2;
                end
                else begin
                    data_mid <= data2;
                    data_min <= data1;
                end
            end
            else if (data1 >= data0 && data1 >= data2) begin
                data_max <= data1;

                if (data0 >= data2) begin
                    data_mid <= data0;
                    data_min <= data2;
                end
                else begin
                    data_mid <= data2;
                    data_min <= data0;
                end
            end
            else begin
                data_max <= data2;

                if (data0 >= data1) begin
                    data_mid <= data0;
                    data_min <= data1;
                end
                else begin
                    data_mid <= data1;
                    data_min <= data0;
                end 
            end
        end
    end

    always @(posedge clk or posedge rst_p) begin    // 输出数据有效信号，同样经过寄存器同步输出
        if (rst_p) begin
            data_out_valid <= 1'b0;
        end
        else if (data_in_valid) begin
            data_out_valid <= 1'b1;
        end
        else begin
            data_out_valid <= 1'b0;
        end
    end
endmodule
