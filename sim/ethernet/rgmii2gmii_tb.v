`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/22 17:13:06
// Design Name: Ethernet MAC
// Module Name: rgmii2gmii_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for RGMII to GMII converter
// 
// Dependencies: rgmii2gmii.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rgmii2gmii_tb(

    );
    reg rx_clk;                 // 输入锁相环的时钟，仍然是125MHz
    wire locked;                // 锁相环锁定信号

    reg reset_n;
    wire rgmii_rx_clk;          // 该时钟经过锁相环处理后输出
    reg [3:0] rgmii_rxd;
    reg rgmii_rx_ctl;

    wire gmii_rx_clk;
    wire [7:0] gmii_rxd;
    wire gmii_rx_er;
    wire gmii_rx_dv;

    reg [3:0] rgmii_rx_cnt;     // 设置一计数器用于循环施加rgmii_rxd数据激励

    // Instantiate the rgmii2gmii module
    rgmii2gmii rgmii2gmii_inst(
        .reset_n        (reset_n),
        .rgmii_rx_clk   (rgmii_rx_clk),
        .rgmii_rxd      (rgmii_rxd),
        .rgmii_rx_ctl   (rgmii_rx_ctl),

        .gmii_rx_clk    (gmii_rx_clk),
        .gmii_rxd       (gmii_rxd),
        .gmii_rx_er     (gmii_rx_er),
        .gmii_rx_dv     (gmii_rx_dv)
    );

    // Instantiate the PLL for clock generation
    rgmii2gmii_clk_pll rgmii2gmii_clk_pll_inst(
        .clk_in         (rx_clk),
        .reset          (!reset_n),
        .clk_out        (rgmii_rx_clk),
        .locked         (locked)
    );

    // Clock generation
    initial begin
        rx_clk <= 1'b1;
        forever #4 rx_clk <= !rx_clk; // 125 MHz clock
    end

    // Counter for stimulus generation
    always @(rx_clk or negedge reset_n)     // 这里rx_clk不加边沿检测是为了保证输入的rgmii_rxd数据是双沿触发的
        if (!reset_n)
            rgmii_rx_cnt <= 4'b0;
        else if (rgmii_rx_ctl && locked)    // 如果RGMII接收控制信号有效且PLL已锁定
            rgmii_rx_cnt <= rgmii_rx_cnt + 1'b1;
        else
            rgmii_rx_cnt <= 4'b0;

    always @(*)     // 组合逻辑，根据计数器生成rgmii_rxd激励数据
        case (rgmii_rx_cnt)
            4'b0000: rgmii_rxd = 4'h0;
            4'b0001: rgmii_rxd = 4'h1;
            4'b0010: rgmii_rxd = 4'h2;
            4'b0011: rgmii_rxd = 4'h3;
            4'b0100: rgmii_rxd = 4'h4;
            4'b0101: rgmii_rxd = 4'h5;
            4'b0110: rgmii_rxd = 4'h6;
            4'b0111: rgmii_rxd = 4'h7;
            4'b1000: rgmii_rxd = 4'h8;
            4'b1001: rgmii_rxd = 4'h9;
            4'b1010: rgmii_rxd = 4'hA;
            4'b1011: rgmii_rxd = 4'hB;
            4'b1100: rgmii_rxd = 4'hC;
            4'b1101: rgmii_rxd = 4'hD;
            4'b1110: rgmii_rxd = 4'hE;
            4'b1111: rgmii_rxd = 4'hF;
            default: rgmii_rxd = 4'h0; // Default case
        endcase

    // Simulation
    initial begin
        reset_n <= 1'b0;            // 初始复位信号为低
        rgmii_rx_ctl <= 1'b0;       // RGMII接收控制信号初始为无效
        rgmii_rxd <= 4'h0;          // RGMII接收数据初始为无效

        repeat (10) @(posedge rx_clk);
        reset_n <= 1'b1;            // 释放复位信号
        rgmii_rx_ctl <= 1'b1;       // 激活RGMII接收控制信号

        repeat (200) @(posedge rx_clk); // 等待200个时钟周期以观察输出
        $finish;                    // 结束仿真
    end
endmodule
