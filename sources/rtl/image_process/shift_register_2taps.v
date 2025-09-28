`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/03/30 17:38:36
// Design Name: Module to connect ram_based shift register IP
// Module Name: shift_register_2taps
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: 将Xilinx Vivado中生成的RAM-based Shift Register IP连接起来，
// 形成一个位宽为8位的、位深度总和为1280*2位的移位寄存器，以寄存两行图像数据，
// 用于后续中值滤波、边缘检测等模块的行寄存
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 
// 1. taps1x为高位移位寄存器的输出，taps0x为低位移位寄存器的输出
//*2. 本模块可寄存行宽为1280像素的图像数据共两行，分别以taps1x、taps0x作为上一行、上上行数据的串行输出端口
//*3. 由于Vivado中生成的RAM-based Shift Register IP最大深度限制为1088，单个IP无法满足寄存1280像素行宽的需求，
//*   因此调用IP核深度设置为**640**像素，由2个IP级联实现单行像素的缓存，因此缓存两行像素共需要4次IP调用
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

    wire [DATA_WIDTH-1:0] taps_reg_1;       // 用于第一个640深度寄存器的中间输出连接
    wire [DATA_WIDTH-1:0] taps_reg_0;       // 用于第三个640深度寄存器的中间输出连接

    shift_reg_ram shift_reg_ram_inst3 (
        .D      (dat_in),
        .CLK    (clk),
        .CE     (dat_in_valid),
        .Q      (taps_reg_1)
    );

    shift_reg_ram shift_reg_ram_inst2 (
        .D      (taps_reg_1),
        .CLK    (clk),
        .CE     (dat_in_valid),
        .Q      (taps1x)
    );

    shift_reg_ram shift_reg_ram_inst1 (
        .D      (taps1x),
        .CLK    (clk),
        .CE     (dat_in_valid),
        .Q      (taps_reg_0)
    );

    shift_reg_ram shift_reg_ram_inst0 (
        .D      (taps_reg_0),
        .CLK    (clk),
        .CE     (dat_in_valid),
        .Q      (taps0x)
    );
endmodule
