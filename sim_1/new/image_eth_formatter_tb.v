`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/29 19:48:44
// Design Name: Ethernet Image Formatter
// Module Name: image_eth_formatter_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for image_eth_formatter module
// 
// Dependencies: image_eth_formatter.v
// 
// Revision:
// [2025/7/29] Revision 0.01 - File Created
// [2025/7/30] Revision 0.02 - 修改了testbench逻辑使之与修改后的主模块契合
// Additional Comments:
// 1. 认为行场同步信号、数据有效信号均在发送最后一个像素时有效，而非发送完最后一个像素后才有效
// 2. 该testbench模拟了两帧数据，每帧3行，每行16像素，即每行发送16/8 + 2 = 4 Bytes
// 3. 每行像素数据发送完毕后，至少等待3拍时钟周期，才能开始下一行的输入
// 4. 注意testbench中时钟信号、异步控制信号应当采用阻塞赋值，同步数据信号采用非阻塞赋值
//////////////////////////////////////////////////////////////////////////////////


module image_eth_formatter_tb(

    );

    //* Step 1: Module Instantiation
    reg clk_pixel;
    reg rst_n;
    reg valid;
    reg hsync;
    reg vsync;
    reg sobel;

    wire fifo_aclr;
    wire [7:0] write_data;
    wire write_req;

    image_eth_formatter image_eth_formatter_inst (
        // inputs
        .clk_pixel      (clk_pixel),
        .rst_n          (rst_n),
        .valid          (valid),
        .hsync          (hsync),
        .vsync          (vsync),
        .sobel          (sobel),
        // outputs
        .fifo_aclr      (fifo_aclr),
        .write_data     (write_data),
        .write_req      (write_req)
    );

    //* Step 2: Clock Generation
    // 使用阻塞赋值
    initial begin
        clk_pixel = 1'b0;
        forever #5 clk_pixel = ~clk_pixel; // 100MHz clock
    end

    //* Step 3: Asynchronous Reset
    // 使用阻塞赋值
    initial begin
        rst_n = 1'b0;      // 复位
        repeat (10) @(posedge clk_pixel); // 等待10个时钟周期
        rst_n = 1'b1;      // 解除复位
    end

    //* Step 4: Data Simulation
    // 使用非阻塞赋值
    initial begin
        valid <= 1'b0;
        hsync <= 1'b0;
        vsync <= 1'b0;
        sobel <= 1'b0;
        @ (posedge rst_n);          // 等待复位解除
        repeat (10) @(posedge clk_pixel); // 等待10个时钟周期

        repeat (2) begin            // 发送两帧数据，每帧3行，每行16像素，即每行发送16/8 + 2 = 4 Bytes
            repeat (8) @(posedge clk_pixel) begin // 模拟第一行像素
                sobel <= 1'b1;      // 反复发送1
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            repeat (8) @(posedge clk_pixel) begin   // 模拟第一行像素
                sobel <= ~sobel;    // 反复发送010101
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            hsync <= 1'b0;          // 第一行像素发送完毕
                                    //* 这里这些同步信号均在发送最后一个像素时有效，而非发送完最后一个像素后才有效，testbench的验证是基于此完成的
            repeat (3) @(posedge clk_pixel);        //! Alert: 在每一行像素输入完毕后，至少要等待3个时钟周期，才能开始下一行的输入

            repeat (16) @(posedge clk_pixel) begin  // 模拟第二行像素
                sobel <= 1'b1;      // 反复发送1
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            hsync <= 1'b0;          // 第二行像素发送完毕
            repeat (3) @(posedge clk_pixel);

            repeat (16) @(posedge clk_pixel) begin  // 模拟第三行像素
                sobel <= 1'b0;      // 反复发送0
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            hsync <= 1'b0;          // 第三行像素发送完毕
            vsync <= 1'b0;          // 该帧像素发送完毕
            valid <= 1'b0;
            repeat (3) @(posedge clk_pixel);
        end

        repeat (10) @(posedge clk_pixel);

        $finish;
    end

endmodule
