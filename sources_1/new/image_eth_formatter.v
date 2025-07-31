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
// Description: 将前述图像预处理模块输出的SOBEL二值图像数据打包为行号＋像素数据，按照字节单位写入FIFO，便于通过以太网传输
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 1. 该模块以行为单位对图像进行打包，并对每一行进行编号，编号位宽为2字节，置于每行像素最前方
// 2. 采用FIFO缓冲区存储打包后的数据，便于后续的以太网发送模块处理
// 3. 图像单帧尺寸设置为1280*720像素，以太网每帧传输数据大小为1280*1/8 + 2 = 162Bytes
//?4. 目前对于图像的行同步、场同步信号行为不是很明确，需要等待后续ov5640驱动模块编写完成后再做优化
//*5. 由于加入了2字节行号，加之一段式状态机本身的单拍延时特性，写入FIFO的数据将会延迟3拍完成，
//!   也就是说，输入像素数据每行之间至少间隔3拍时钟周期，才能保证数据的正确性，
//!   对应于行同步信号，便是在像素数据传输结束后（行同步信号变为无效后），至少等待3拍时钟周期，该信号才能再次有效，
//*   当切换帧时，场同步信号、数据有效信号同样需要至少等待3拍
// 6. 由于图像预处理模块输出的SOBEL二值图像数据位宽为1位，而FIFO的写入数据位宽为8位，
//    因此，在对FIFO写入像素数据时（以字节为单位写入），每隔8拍时钟周期，才会写入一次，
//    而写入行号时则是连续写入的
//?7. 目前认为场同步信号在每帧图像传输完成后拉低（无效）
//?   行同步信号在每行传输完成后拉低（无效）
//////////////////////////////////////////////////////////////////////////////////


module image_eth_formatter(
    input clk_pixel,            // 像素时钟
    input rst_n,                // 复位信号，低有效
    input valid,                // 输入数据有效标志
    input hsync,                // 行同步信号
    input vsync,                // 场同步信号
    input sobel,                // SOBEL算子边缘检测后的像素数据输入

    output reg fifo_aclr,       // FIFO异步清零信号
    output reg [7:0] write_data,// 写入FIFO的数据
    output reg write_req        // 写入FIFO请求信号
    );

    //* Step 1: 变量声明
    reg [15:0] line_count;      // 行计数器，用于记录当前行号
    reg [2:0] hsync_reg;        // 行同步信号寄存器，用于处理行同步信号的延时
    reg [2:0] sobel_reg;        // SOBEL输出像素寄存器，用于在发送行号的时候对像素数据进行寄存
                                // 发送行号需要2拍，状态机切换需要1拍，因此寄存3位

    //* Step 2: 行同步信号及SOBEL像素寄存
    always @(posedge clk_pixel) begin
        hsync_reg <= {hsync_reg[1:0], hsync};         // 行同步信号寄存，便于得知此时发送数据的状态
        sobel_reg <= {sobel_reg[1:0], sobel};         // SOBEL像素数据寄存，便于在头部发送行号
    end

    //* Step 3: FIFO清零信号控制
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n)
            fifo_aclr <= 1'b1;      // 复位时清零FIFO
        else    
            fifo_aclr <= 1'b0;      //! 注意：FIFO清零信号无效后需要等待足够长的时钟周期（约25拍）才能对FIFO进行读写

    //* Step 4: 数据打包发送逻辑
    // NOTE: 由于此处存入FIFO的数据位宽必须为8位，而SOBEL算子输出的二值图像数据位宽为1位，
    //       因此在这里数据的打包逻辑为与以太网收发一致的序列机（一段式状态机）
    //       分为空闲、发送行号、发送像素数据三种状态
    //       空闲状态下根据行同步信号进入发送状态
    //       每种状态下分设发送计数器，便于对发送数据和发送请求进行控制
    localparam [2:0] IDLE = 3'b001;         // 空闲状态
    localparam [2:0] SEND_LINE = 3'b010;    // 发送行号状态
    localparam [2:0] SEND_PIXEL = 3'b100;   // 发送像素数据状态

    reg [2:0] state;                        // 状态寄存器
    reg [3:0] cnt_send;                     // 发送计数器，用于控制发送数据
                                            // 当然，事实上3 bit计数模8足够了，留了1 bit冗余
    
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n) begin
            state <= IDLE;                          // 复位时进入空闲状态
            cnt_send <= 4'b0;                       // 发送计数器清零
            write_data <= 8'b0;                     // 清除写入数据
            write_req <= 1'b0;                      // 清除写入请求信号
        end
        else
            case (state)
                IDLE: begin
                    write_data <= 8'b0;             // 空闲状态下清除写入数据
                    write_req <= 1'b0;              // 清除写入请求信号
                    cnt_send <= 4'b0;               // 清除发送计数器

                    if (({hsync_reg[0], hsync} == 2'b01) && valid)
                        state <= SEND_LINE;         // 当行同步信号有效且数据有效时进入发送行号状态
                end

                SEND_LINE: begin
                    if (cnt_send >= 1) begin
                        cnt_send <= 4'b0;
                        state <= SEND_PIXEL;        // 发送行号后进入发送像素数据状态
                    end
                    else
                        cnt_send <= cnt_send + 1'b1;// 发送计数器加一

                    write_data <= cnt_send == 0 ? line_count[7:0] : line_count[15:8]; // 发送行号的低8位和高8位
                    write_req <= 1'b1;              // 发送行号时请求写入始终是有效的
                    //? 可能需要在cnt_send == 1时将write_req清零以满足时序，即可能需要将write_req整体前移一拍（目前来看不需要）
                end

                SEND_PIXEL: begin
                    if (cnt_send >= 7) begin
                        cnt_send <= 4'b0;
                        if (!(hsync_reg[2] || hsync_reg[1])) // 此处逻辑可以根据需要更改为if (!(hsync_reg[2] || hsync))，这是最严格的条件
                            state <= IDLE;          // 如果hsync在延时3拍后为0，意味着当前行（包括行号）已经发送完毕
                    end
                    else
                        cnt_send <= cnt_send + 1'b1;

                    write_req <= (cnt_send >= 7) ? 1'b1 : 1'b0;     // 在发送像素数据时，只有在计数器达到7时才发送请求
                    write_data <= {write_data[6:0], sobel_reg[2]};  // SOBEL像素数据不断移位
                    //* 该状态的本质仍然是8 bit串入并出移位寄存器
                end
            endcase

    //* Step 6: 行计数器更新
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n)
            line_count <= 16'b0;                // 复位时清零行计数器
        else if (!vsync)
            line_count <= 16'b0;                // 场同步信号无效（发送结束一帧图像时）时清零行计数器
        else if ({hsync_reg[0], hsync} == 2'b10)    
            line_count <= line_count + 1'b1;    // 当当前行（不含行号）发送完毕时，行计数器加一

endmodule
