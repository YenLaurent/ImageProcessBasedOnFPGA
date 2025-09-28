`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/22 16:15:13
// Design Name: Ethernet MAC
// Module Name: gmii2rgmii_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for gmii2rgmii module.
// 
// Dependencies: gmii2rgmii.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module gmii2rgmii_tb(

    );
    // Testbench signals
    reg reset_n;
    reg gmii_tx_clk;
    reg [7:0] gmii_txd;
    reg gmii_tx_en;
    reg gmii_tx_er;

    wire [3:0] rgmii_txd;
    wire rgmii_tx_clk;
    wire rgmii_tx_ctl;

    reg [3:0] gmii_tx_cnt;  // 设置一计数器用于循环施加gmii_txd数据激励

    // Instantiate the gmii2rgmii module
    gmii2rgmii gmii2rgmii_inst(
        .reset_n        (reset_n),
        .gmii_tx_clk    (gmii_tx_clk),
        .gmii_txd       (gmii_txd),
        .gmii_tx_en     (gmii_tx_en),
        .gmii_tx_er     (gmii_tx_er),

        .rgmii_txd      (rgmii_txd),
        .rgmii_tx_clk   (rgmii_tx_clk),
        .rgmii_tx_ctl   (rgmii_tx_ctl)
    );

    // Clock generation
    initial begin
        gmii_tx_clk <= 1'b1;
        forever #4 gmii_tx_clk <= !gmii_tx_clk; // 125 MHz clock
    end

    // Stimulus generation
    always @(posedge gmii_tx_clk or negedge reset_n)
        if (!reset_n)           // Asynchronous reset
            gmii_tx_cnt <= 4'b0;
        else if (gmii_tx_en)    // If GMII transmit is enabled
            gmii_tx_cnt <= gmii_tx_cnt + 1;
        else
            gmii_tx_cnt <= 4'b0;

    always @(*)     // 组合逻辑，根据计数器生成gmii_txd激励数据
        case (gmii_tx_cnt)
            4'b0000: gmii_txd = 8'h0A; // Example data
            4'b0001: gmii_txd = 8'h1B;
            4'b0010: gmii_txd = 8'h2C;
            4'b0011: gmii_txd = 8'h3D;
            4'b0100: gmii_txd = 8'h4E;
            4'b0101: gmii_txd = 8'h5F;
            4'b0110: gmii_txd = 8'h60;
            4'b0111: gmii_txd = 8'h71;
            4'b1000: gmii_txd = 8'h82;
            4'b1001: gmii_txd = 8'h93;
            4'b1010: gmii_txd = 8'hA4;
            4'b1011: gmii_txd = 8'hB5;
            4'b1100: gmii_txd = 8'hC6;
            4'b1101: gmii_txd = 8'hD7;
            4'b1110: gmii_txd = 8'hE8;
            4'b1111: gmii_txd = 8'hF9;
            default: gmii_txd = 8'h00; // Default case
        endcase

    // Simulation
    initial begin
        $display("Simulation starts at time %0t", $realtime);
        reset_n <= 1'b0;
        gmii_tx_en <= 1'b0;
        gmii_tx_er <= 1'b0;
        repeat (16) @(posedge gmii_tx_clk); // Wait for 16 clock cycles

        reset_n <= 1'b1; // Release reset
        gmii_tx_en <= 1'b1; // Enable GMII transmit
        repeat (200) @(posedge gmii_tx_clk); // Run for 200 clock cycles

        $display("Simulation ends at time %0t", $realtime);
        $finish; // End simulation
    end
endmodule
