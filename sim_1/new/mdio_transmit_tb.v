`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/28 21:17:16
// Design Name: Ethernet PHY Configuration
// Module Name: mdio_transmit_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for Ethernet PHY Configuration Module
// 
// Dependencies: mdio_transmit.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mdio_transmit_tb(

    );

    //* Step 1: 输入输出端口及例化
    reg mdc;                  // MDIO时钟信号
    reg reset_n;              // 复位信号，低有效
    reg start;                // 启动信号，开始MDIO传输
    reg read;                 // 读操作标志，1表示读操作，0表示
    reg [4:0] phy_addr;       // PHY地址
    reg [4:0] reg_addr;       // 寄存器地址
    reg [15:0] write_data;    // 写操作时的数据

    wire done;                // 传输完成标志
    wire [15:0] read_data;    // 读操作时的数据
    wire mdio;                // MDIO数据线

    mdio_transmit mdio_transmit_inst(
        // input
        .mdc        (mdc),
        .reset_n    (reset_n),
        .start      (start),
        .read       (read),
        .phy_addr   (phy_addr),
        .reg_addr   (reg_addr),
        .write_data (write_data),
        // output
        .done       (done),
        .read_data  (read_data),
        .mdio       (mdio)
    );

    //* Step 2: 时钟生成
    initial begin
        mdc <= 1'b0;
        forever #10 mdc <= !mdc; // 50 MHz clock for MDIO
    end

    //* Step 3: 激励生成
    initial begin
        reset_n <= 1'b0;
        read <= 1'b0;
        phy_addr <= 5'b00001;   // PHY地址为1
        reg_addr <= 5'b00010;   // 寄存器地址取2
        write_data <= 16'h1234; // 写入数据为0x1234
        start <= 1'b0;
        #200;

        reset_n <= 1'b1;        // 释放复位
        read <= 1'b0;           // 写操作
        @(posedge mdc);         // 等待MDIO时钟上升沿
        start <= 1'b1;          // 启动MDIO传输
        @(posedge done);
        #200;
        $finish;
    end
endmodule
