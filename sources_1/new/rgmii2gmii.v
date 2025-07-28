`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/21 19:18:45
// Design Name: Ethernet MAC
// Module Name: rgmii2gmii
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: RGMII to GMII converter, used to convert RGMII signals to GMII signals for Ethernet communication.
// 
// Dependencies: IDDR primitive.
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 这一部分与GMII转RGMII类似，同样例化IDDR原语来处理RGMII的输入数据和控制信号即可
// 该部分用于FPGA通过以太网接收数据，将收到的RGMII数据转换为GMII数据，时钟信号由PHY侧提供
// 注意：为了保证建立时间和保持时间，RGMII的时钟信号需要和数据信号呈90°相移，这一相移一般可由PHY自动完成，但是在testbench中，
// 需要手动采用PLL处理时钟信号的相移
//////////////////////////////////////////////////////////////////////////////////


module rgmii2gmii(
    input       reset_n,       // Reset signal, active low
    input       rgmii_rx_clk,  // RGMII receive clock
    input [3:0] rgmii_rxd,     // RGMII receive data
    input       rgmii_rx_ctl,  // RGMII receive control

    output       gmii_rx_clk,   // GMII receive clock
    output [7:0] gmii_rxd,      // GMII receive data
    output       gmii_rx_er,    // GMII receive error
    output       gmii_rx_dv     // GMII receive data valid
    );

    assign gmii_rx_clk = rgmii_rx_clk; // GMII clock is same as RGMII clock

    // Step 1. IDDR instance for GMII receive data
    genvar i;
    generate
        for (i=0; i<4; i=i+1) begin: gen_iddr_rxd
            IDDR #(
                .DDR_CLK_EDGE   ("SAME_EDGE_PIPELINED"),        // "OPPOSITE_EDGE" or "SAME_EDGE"
                .INIT_Q1        (1'b0),                         // Initial value of Q
                .INIT_Q2        (1'b0),                         // Initial value of Q
                .SRTYPE         ("SYNC")                        // Set/Reset type: "SYNC" or "ASYNC"
            ) IDDR_rxd_inst (
                .Q1 (gmii_rxd[i]),                // Data output for rising edge
                .Q2 (gmii_rxd[i+4]),              // Data output for falling edge
                .C  (rgmii_rx_clk),               // Clock input
                .CE (1'b1),                       // Clock enable
                .D  (rgmii_rxd[i]),               // Data input
                .R  (!reset_n),                   // Reset signal, active low
                .S  (1'b0)                        // Set signal, not used
            );
        end
    endgenerate

    // Step 2. IDDR instance for GMII receive control
    IDDR #(
        .DDR_CLK_EDGE   ("SAME_EDGE_PIPELINED"),        // "OPPOSITE_EDGE" or "SAME_EDGE"
        .INIT_Q1        (1'b0),                         // Initial value of Q
        .INIT_Q2        (1'b0),                         // Initial value of Q
        .SRTYPE         ("SYNC")                        // Set/Reset type: "SYNC" or "ASYNC"
    ) IDDR_ctl_inst (
        .Q1 (gmii_rx_dv),                   // Data output for rising edge
        .Q2 (gmii_rx_er),                   // Data output for falling edge
        .C  (rgmii_rx_clk),                 // Clock input
        .CE (1'b1),                         // Clock enable
        .D  (rgmii_rx_ctl),                 // Data input
        .R  (!reset_n),                     // Reset signal, active low
        .S  (1'b0)                          // Set signal, not used
    );

endmodule