`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/03/30 17:38:36
// Design Name: Module to connect 2 ram_based shift register IP
// Module Name: shift_register_2taps
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 将Xilinx Vivado中生成的RAM-based Shift Register IP（8位位宽，深度为400）连接起来，形成一个2tap的移位寄存器
// 每个移位寄存器都可以存储一行图像数据（要求图像尺寸长400像素），级联后可存储两行，接收输入灰度8位图像数据，串行输出
// （每次8位）两行（长度400位）数据
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: taps1x为高位移位寄存器的输出，taps0x为低位移位寄存器的输出
// 
//////////////////////////////////////////////////////////////////////////////////


module shift_register_2taps #(
    parameter DATA_WIDTH = 8                // 数据位宽，如需改动需要更改IP
    )(
    input clk,                              // 时钟信号
    input [DATA_WIDTH-1:0] dat_in,          // 输入数据
    input dat_in_valid,                     // 输入数据有效信号
    output [DATA_WIDTH-1:0] dat_out,        // 输出数据
    output [DATA_WIDTH-1:0] taps1x, taps0x  // 输出两个移位寄存器的输出
    );

    assign dat_out = taps0x; // 输出信号即最低位移位寄存器的输出

    shift_reg_ram shift_reg_ram_inst1 (
        .D      (dat_in),
        .CLK    (clk),
        .CE     (dat_in_valid),
        .Q      (taps1x)
    );

    shift_reg_ram shift_reg_ram_inst0 (
        .D      (taps1x),
        .CLK    (clk),
        .CE     (dat_in_valid),
        .Q      (taps0x)
    );
endmodule
