`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/31 16:29:03
// Design Name: Ethernet Top Module
// Module Name: ethernet_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Ethernet Top Module Testbench
// 
// Dependencies: ethernet.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ethernet_tb(

    );

    //* Step 1: 输入输出端口及例化
    reg clk_100mhz;             // 100MHz时钟
    reg clk_125mhz;             // 125MHz时钟
    reg clk_50mhz;              // 50MHz时钟
    reg rst_n;                  // 复位信号，低电平有效
    reg valid;                  // 输入数据有效标志
    reg hsync;                  // 行同步信号
    reg vsync;                  // 场同步信号
    reg sobel;                  // SOBEL算子边缘检测后的像素数据输入

    wire [3:0] rgmii_txd;       // RGMII发送数据
    wire rgmii_tx_clk;          // RGMII发送时钟
    wire rgmii_tx_ctl;          // RGMII发送控制信号
    wire phy_rst_n;             // PHY复位信号
    wire phy_config_done;       // PHY配置完成标志
    wire [15:0] phy_read_data;  // 读取的寄存器数据
    wire mdc;                   // MDC时钟信号
    wire mdio;                  // MDIO数据线

    ethernet #(
        .IMAGE_WIDTH            (1280),
        .IMAGE_HEIGHT           (3),                        // 测试用3行图像
        .ETHERNET_SPEED         (2'b10),                    // 千兆以太网
        .DES_MAC                (48'hff_ff_ff_ff_ff_ff),    // 广播地址
        .SRC_MAC                (48'h00_0a_35_01_fe_c0),    // 源MAC地址
        .DES_IP                 (32'hc0_a8_00_03),          // 目标IP地址
        .SRC_IP                 (32'hc0_a8_00_02),          // 源IP地址
        .DES_UDP_PORT           (16'd6102),                 // 目标UDP端口号
        .SRC_UDP_PORT           (16'd5000),                 // 源UDP端口号
        .DATA_LENGTH            (162)                       // 用户单帧数据长度
    ) ethernet_inst (
        // inputs
        .clk_pixel              (clk_100mhz),
        .clk_eth                (clk_125mhz),
        .clk_phy                (clk_50mhz),
        .rst_n                  (rst_n),
        .valid                  (valid),
        .hsync                  (hsync),
        .vsync                  (vsync),
        .sobel                  (sobel),
        // outputs
        .rgmii_txd              (rgmii_txd),
        .rgmii_tx_clk           (rgmii_tx_clk),
        .rgmii_tx_ctl           (rgmii_tx_ctl),
        .phy_config_done        (phy_config_done),
        .phy_read_data          (phy_read_data),
        .mdc                    (mdc),
        .mdio                   (mdio),
        .fifo_read_usage        (fifo_read_usage)
    );

    //* Step 2: 时钟生成
    initial begin
        clk_100mhz = 1'b0;
        forever #5 clk_100mhz = !clk_100mhz; // 100MHz clock for image process
    end

    initial begin
        clk_125mhz = 1'b0;
        forever #4 clk_125mhz = !clk_125mhz; // 125MHz clock for Ethernet
    end

    initial begin
        clk_50mhz = 1'b0;
        forever #10 clk_50mhz = !clk_50mhz;  // 50MHz clock for PHY config
    end

    //* Step 3: 异步控制信号
    initial begin
        rst_n = 1'b0;                        // 复位信号初始为低
        repeat (20) @(posedge clk_100mhz);   // 等待20个时钟周期
        rst_n = 1'b1;                        // 复位信号拉高
    end

    //* Step 4: 激励生成
    initial begin
        valid <= 1'b0;
        hsync <= 1'b0;
        vsync <= 1'b0;
        sobel <= 1'b0;
        // @ (posedge phy_config_done);        // 等待PHY配置完成（只需要在初次运行时配置PHY即可，配置较慢，因此在后续的TESTBENCH中可以省略）
        repeat (100) @(posedge clk_100mhz);  // 等待100个时钟周期，保证FIFO初始化完毕

        repeat (2) begin                    // 发送2帧数据，每帧3行，每行1280像素，每行需发送162Bytes
            //* 第一行
            repeat (280) @(posedge clk_100mhz) begin
                sobel <= 1'b1;      // 反复发送280个像素的1'b1作为起始标志
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            repeat (1000) @(posedge clk_100mhz) begin
                sobel <= ~sobel;    // 反复发送1000个像素的010101
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            hsync <= 1'b0;          // 第一行像素发送完毕
            repeat (10) @(posedge clk_100mhz);        // 等待10个时钟周期（至少需要等待3个时钟周期）
            
            //* 第二行
            repeat (280) @(posedge clk_100mhz) begin
                sobel <= 1'b0;      // 反复发送280个像素的1'b0作为起始标志
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            repeat (1000) @(posedge clk_100mhz) begin
                sobel <= ~sobel;    // 反复发送1000个像素的101010
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            hsync <= 1'b0;          // 第二行像素发送完毕
            repeat (10) @(posedge clk_100mhz);        // 等待10个时钟周期（至少需要等待3个时钟周期）
        
            //* 第三行
            repeat (280) @(posedge clk_100mhz) begin
                sobel <= 1'b0;      // 反复发送280个像素的1'b0作为起始标志
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            repeat (1000) @(posedge clk_100mhz) begin
                sobel <= ~sobel;    // 反复发送1000个像素的101010
                valid <= 1'b1;
                hsync <= 1'b1;      // 当前行同步信号有效
                vsync <= 1'b1;
            end

            hsync <= 1'b0;          // 第三行像素发送完毕
            vsync <= 1'b0;          // 该帧像素发送完毕
            valid <= 1'b0;          // 清除数据有效标志
            repeat (10) @(posedge clk_100mhz);        // 等待10个时钟周期（至少需要等待3个时钟周期）
        end

        repeat (50) @(posedge clk_100mhz);  // 等待50个时钟周期，便于观察结果
        $finish;                            // 结束仿真
    end

endmodule
