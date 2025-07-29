`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/29 18:31:13
// Design Name: Ethernet Image Formatter
// Module Name: image_eth_formatter
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 将前述图像预处理模块输出的二值图像数据打包为以太网帧格式，便于通过以太网传输
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 1. 该模块以行为单位对图像进行打包，并对每一行进行编号，编号位宽为2字节，置于每行像素最前方
// 2. 采用FIFO缓冲区存储打包后的数据，便于后续的以太网发送模块处理
// 3. 图像单帧尺寸设置为1280*720像素，以太网每帧传输数据大小为1280*1/8 + 2 = 162Bytes
//?4. 该模块输入[7:0]位宽的数据，这与SOBEL模块输出的二值图像位宽似乎不一致
//?5. 目前对于图像的行同步、场同步信号行为不是很明确，需要等待后续ov5640驱动模块编写完成后再做优化
//////////////////////////////////////////////////////////////////////////////////


module image_eth_formatter(
    input clk_pixel,            // 像素时钟
    input rst_n,                // 复位信号，低有效
    input valid,                // 输入数据有效标志
    input hsync,                // 行同步信号
    input vsync,                // 场同步信号
    input [7:0] pixel_data,     // 像素数据输入

    output reg fifo_aclr,       // FIFO异步清零信号
    output [7:0] write_data,    // 写入FIFO的数据
    output reg write_req        // 写入请求信号
    );

    //* Step 1: 变量声明
    reg [23:0] data_buffer;     // 数据缓冲区，用于存储打包后的数据
    reg [15:0] line_count;      // 行计数器，用于记录当前行号
    reg [1:0] hsync_reg;        // 行同步信号寄存器，用于处理行同步信号的延时

    //* Step 2: 行同步信号寄存
    assign write_data = data_buffer[23:16];     // 写入FIFO的数据为打包后的数据的高8位

    always @(posedge clk_pixel)
        hsync_reg[1:0] <= {hsync_reg[0], hsync};     // 行同步信号寄存，便于得知此时发送数据的状态

    //* Step 3: FIFO清零信号控制
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n)
            fifo_aclr <= 1'b1;      // 复位时清零FIFO
        else if (vsync && valid)    
            fifo_aclr <= 1'b0;      // 场同步信号有效且数据有效时停止清零FIFO，开始写入

    //* Step 4: 数据打包逻辑
    // 本质上该部分是并入串出移位寄存器，
    // 当场同步信号位于新行开始时（即当前场同步信号有效，但上一拍场同步信号无效）一次性加载初始数据，
    // 随后不断将新像素数据pixel_data移入寄存器，直到下一行开始
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n)
            data_buffer <= 24'b0;    // 复位时清空数据缓冲区
        else if ({hsync_reg[0], hsync} == 2'b01)
            data_buffer <= {line_count[7:0], line_count[15:8], pixel_data}; // 新行开始时打包行号和像素数据
            // 注意此处发送时首先发送行号的低8位，然后才是高8位，最后是像素数据
        else 
            data_buffer <= {data_buffer[15:0], pixel_data}; // 否则继续填充像素数据

    //* Step 5: 写入请求信号控制
    always @(posedge clk_pixel)
        if ({hsync_reg[0], hsync} == 2'b01)
            write_req <= 1'b1;          // 新行开始时发出写入请求信号
        else if (hsync_reg[1] || hsync_reg[0])
            write_req <= 1'b1;          // 只要行同步信号在两拍内还有效，便维持写入请求信号
                                        // 即实际上的输出数据会因为data_buffer的移位而首先延迟一拍
                                        // 再加上首部的2字节行号数据，整体数据就会延迟3拍完成发送
                                        // 这也是为什么要设置两位行同步信号寄存器的原因
        else
            write_req <= 1'b0;          // 否则清除写入请求

    //* Step 6: 行计数器更新
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n)
            line_count <= 16'b0;                // 复位时清零行计数器
        else if (!vsync)
            line_count <= 16'b0;                // 场同步信号无效（发送结束一帧图像时）时清零行计数器
        else if ({hsync_reg[0], hsync} == 2'b10)    
            line_count <= line_count + 1'b1;    // 当当前行发送完毕时，行计数器加一

endmodule
