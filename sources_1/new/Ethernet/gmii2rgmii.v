`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/21 19:18:45
// Design Name: Ethernet MAC
// Module Name: gmii2rgmii
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 以太网数据链路层接口转换器，GMII to RGMII converter
// used to convert GMII signals to RGMII signals for Ethernet communication.
// 
// Dependencies: ODDR primitive.
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: RGMII的数据输出接口在上升沿发送GMII的数据低四位，下降沿发送GMII的数据高四位
// RGMII的控制信号在上升沿发送GMII接口的有效信号，下降沿发送GMII接口的错误信号
// RGMII的时钟输出信号则与GMII一致，仍然采用ODDR寄存器进行输出，以保证其与数据、控制位的同步
//*注意：RGMII的时钟是双沿敏感的，因此需要使用ODDR原语来处理时钟信号
// 该部分用于FPGA通过以太网发送数据，将GMII数据转换为RGMII数据，时钟信号由FPGA MAC提供
// 注意：为了保证建立时间和保持时间，RGMII的输出时钟信号需要和数据信号呈90°相移
// 在这里，由于该模块是发送端，而FPGA开发板上的PHY可以自动对时钟信号进行相移，因此输出的RGMII时钟信号
// 直接与数据信号对齐即可
//////////////////////////////////////////////////////////////////////////////////


module gmii2rgmii(
    input        reset_n,       // Reset signal, active low
    input        gmii_tx_clk,   // GMII transmit clock
    input  [7:0] gmii_txd,      // GMII transmit data
    input        gmii_tx_en,    // GMII transmit enable
    input        gmii_tx_er,    // GMII transmit error

    output [3:0] rgmii_txd,     // RGMII transmit data
    output       rgmii_tx_clk,  // RGMII transmit clock
    output       rgmii_tx_ctl   // RGMII transmit control
    );

    // Step 1. 4 ODDR instances for RGMII data signals 
    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin: gen_oddr_txd
            ODDR #(
                .DDR_CLK_EDGE   ("SAME_EDGE"),      // "OPPOSITE_EDGE" or "SAME_EDGE"
                .INIT           (1'b0),             // Initial value of Q
                .SRTYPE         ("SYNC")            // Set/Reset type: "SYNC" or "ASYNC"
            ) ODDR_inst (
                .Q  (rgmii_txd[i]),           // Data output
                .C  (gmii_tx_clk),            // Clock input
                .CE (1'b1),                   // Clock enable
                .D1 (gmii_txd[i]),            // Data input for rising edge
                .D2 (gmii_txd[i+4]),          // Data input for falling edge
                .R  (!reset_n),               // Reset signal, active low
                .S  (1'b0)                    // Set signal, not used
            );
        end
    endgenerate

    // Step 2. ODDR instance for RGMII transmit clock
    ODDR #(
        .DDR_CLK_EDGE   ("SAME_EDGE"),      // "OPPOSITE_EDGE" or "SAME_EDGE"
        .INIT           (1'b0),             // Initial value of Q
        .SRTYPE         ("SYNC")            // Set/Reset type: "SYNC" or "ASYNC"
    ) ODDR_clk_inst (
        .Q  (rgmii_tx_clk),             // RGMII transmit clock output
        .C  (gmii_tx_clk),              // GMII transmit clock input
        .CE (1'b1),                     // Clock enable
        .D1 (1'b1),                     // Data input for rising edge (high)
        .D2 (1'b0),                     // Data input for falling edge (low)
        .R  (!reset_n),                 // Reset signal, active low
        .S  (1'b0)                      // Set signal, not used
    );

    // Step 3. ODDR instance for RGMII transmit control
    ODDR #(
        .DDR_CLK_EDGE   ("SAME_EDGE"),      // "OPPOSITE_EDGE" or "SAME_EDGE"
        .INIT           (1'b0),             // Initial value of Q
        .SRTYPE         ("SYNC")            // Set/Reset type: "SYNC" or "ASYNC"
    ) ODDR_ctl_inst (
        .Q  (rgmii_tx_ctl),             // RGMII transmit control output
        .C  (gmii_tx_clk),              // GMII transmit clock input
        .CE (1'b1),                     // Clock enable
        .D1 (gmii_tx_en),               // Rising edge: TX_EN
        .D2 (gmii_tx_en ^ gmii_tx_er),  // Falling edge: TX_EN XOR TX_ER (RGMII v2.0)
        .R  (!reset_n),                 // Reset signal, active low
        .S  (1'b0)                      // Set signal, not used
    );

endmodule
