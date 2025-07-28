`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/28 23:49:17
// Design Name: Ethernet PHY Configuration
// Module Name: phy_reg_config_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for Ethernet PHY Configuration Module
// 
// Dependencies: phy_reg_config.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module phy_reg_config_tb(

    );

    //* Step 1: 输入输出端口及例化
    reg clk;                          // 模块系统时钟
    reg rst_n;                        // 复位信号，低电平有效
    wire phy_rst_n;                   // PHY复位信号
    wire [15:0] read_data;            // 读取的寄存器数据
    wire phy_config_done;             // PHY初始化完成标志
    wire mdc;                          // MDC时钟信号
    wire mdio;                        // MDIO数据线

    phy_reg_config #(
        .SPEED      (2'b01),           // 100Mbps
        .MODULE_CLK (50_000_000),      // 模块时钟50MHz
        .MDC_CLK    (2_000),           // MDC时钟2kHz
        .REG2CONFIG (2)                // 配置寄存器个数为2
    ) phy_reg_config_inst (
        .clk                (clk),
        .rst_n              (rst_n),
        .phy_rst_n          (phy_rst_n),
        .read_data          (read_data),
        .phy_config_done    (phy_config_done),
        .mdc                (mdc),
        .mdio               (mdio)
    );

    //* Step 2: 时钟生成
    initial begin
        clk <= 1'b0;
        forever #10 clk <= !clk; // 50 MHz clock for the module
    end

    //* Step 3: 仿真开始
    initial begin
        rst_n <= 1'b0;  // 复位信号初始为低
        #100;           // 等待100ns后释放复位
        rst_n <= 1'b1;  // 释放复位信号

        repeat(10) @(posedge mdc) $display("Caught posedge of mdc at time %t", $realtime);    // 检测分频时钟mdc是否正确

        // 等待PHY配置完成
        wait(phy_config_done);
        repeat(10) @(posedge mdc);          // 等待10个周期以观察结果

        $finish;                            // 结束仿真
    end
endmodule
