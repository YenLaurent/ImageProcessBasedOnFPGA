`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/31 15:42:52
// Design Name: Ethernet Top Module
// Module Name: ethernet
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 以太网发送驱动电路顶层模块，接收图像预处理模块输出的SOBEL二值图像数据，输出以太网UDP/IP协议MAC帧
// 
// Dependencies: udp_send.v, image_eth_formatter.v, gmii2rgmii.v, phy_reg_config.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 1. phy_reg_config.v模块中，MDIO总线时钟由clk_phy配置时钟自动计算得出
// 2. 复位信号rst_n有效后需要等待足够的周期（约25拍）才能对FIFO进行读写
//!3. 实际的vsync信号与本模块vsync逻辑是相反的，即场同步信号在发送完一帧图像后有效，在最终顶层模块例化时一定要特别注意将摄像头模块输出vsync信号取反
//!4. 该模块认为输入数据有效信号与hsync信号是同步的，即在行同步信号有效时，数据有效信号也是有效的，这或许需要后续对摄像头模块、图像预处理模块的信号进行调整
//!   最好是直接在摄像头模块的输出端加上缓冲器以控制数据输出，使得valid信号与hsync信号同步，不再有valid无效的情况，这样可以最大限度避免出错
//!   当然，这会不可避免地将图像处理模块的时钟再次拉低
//////////////////////////////////////////////////////////////////////////////////


module ethernet #(
    parameter IMAGE_WIDTH = 1280,                       // 图像宽度，单位：像素
    parameter IMAGE_HEIGHT = 720,                       // 图像高度，单位：像素
    parameter [1:0] ETHERNET_SPEED = 2'b10,             // 10为千兆，01为百兆，00为十兆
    parameter [47:0] DES_MAC = 48'hff_ff_ff_ff_ff_ff,   // 目标MAC地址，默认为广播地址
    parameter [47:0] SRC_MAC = 48'h00_00_00_00_00_00,   // 源MAC地址，需在实例化时指定
    parameter [31:0] DES_IP = 32'hc0_a8_00_03,          // 目标IP地址，默认为192.168.0.3
    parameter [31:0] SRC_IP = 32'hc0_a8_00_02,          // 源IP地址，默认为192.168.0.2
    parameter [15:0] DES_UDP_PORT = 16'd6102,           // 目标UDP端口号，默认为6102
    parameter [15:0] SRC_UDP_PORT = 16'd5000,           // 源UDP端口号，默认为5000
    parameter [15:0] DATA_LENGTH = IMAGE_WIDTH / 8 + 2  // 用户单帧数据长度（不包含任何报头）
    )(
    input clk_pixel,            //*像素时钟，由OV5640提供，但需分频
    input clk_eth,              // 以太网发送时钟，125MHz
    input clk_phy,              // PHY配置时钟，50MHz
    input rst_n,                // 复位信号，低电平有效
    input valid,                // 输入数据有效标志
    input hsync,                // 行同步信号
    input vsync,                // 场同步信号
    input sobel,                // SOBEL算子边缘检测后的像素数据输入

    output [3:0] rgmii_txd,     // RGMII发送数据线
    output rgmii_tx_clk,        // RGMII发送时钟
    output rgmii_tx_ctl,        // RGMII发送控制信号
    output phy_config_done,     // PHY配置完成标志
    output [15:0] phy_read_data,// 读取的寄存器数据
    output mdc,                 // MDC时钟信号
    inout mdio                  // MDIO数据线
    );

    //* Step 1: Instantiate image formatter module
    wire [7:0] fifo_write_data; // FIFO写入数据
    wire fifo_write_req;        // FIFO写入请求信号
    wire fifo_aclr;             // FIFO异步清零信号

    image_eth_formatter image_eth_formatter_inst(
        // inputs
        .clk_pixel       (clk_pixel),
        .rst_n           (rst_n),
        .valid           (valid),
        .hsync           (hsync),
        .vsync           (vsync),
        .sobel           (sobel),
        // outputs
        .fifo_aclr       (fifo_aclr),
        .write_data      (fifo_write_data),
        .write_req       (fifo_write_req)
    );

    //* Step 2: Instantiate UDP send module
    wire gmii_tx_clk;             // GMII发送时钟信号
    wire [7:0] gmii_txd;          // GMII发送数据
    wire gmii_tx_en;              // GMII发送使能信号
    wire tx_done;                 // 发送完成信号
    wire [11:0] fifo_write_usage; // FIFO写入使用率

    udp_send udp_send_inst(
        // inputs
        .clk_125m          (clk_eth),
        .reset_n           (rst_n),
        .des_mac           (DES_MAC),
        .src_mac           (SRC_MAC),
        .des_udp_port      (DES_UDP_PORT),
        .src_udp_port      (SRC_UDP_PORT),
        .des_ip            (DES_IP),
        .src_ip            (SRC_IP),
        .data_length       (DATA_LENGTH),
        .fifo_write_data   (fifo_write_data),
        .fifo_write_request(fifo_write_req),
        .fifo_write_clk    (clk_pixel),
        .fifo_write_aclr   (fifo_aclr),
        // outputs
        .gmii_tx_clk       (gmii_tx_clk),
        .gmii_txd          (gmii_txd),
        .gmii_tx_en        (gmii_tx_en),
        .tx_done           (tx_done),
        .fifo_write_usage  (fifo_write_usage)
    );

    //* Step 3: Instantiate GMII to RGMII conversion module
    gmii2rgmii gmii2rgmii_inst(
        // inputs
        .reset_n           (rst_n),
        .gmii_tx_clk       (gmii_tx_clk),
        .gmii_txd          (gmii_txd),
        .gmii_tx_en        (gmii_tx_en),
        .gmii_tx_er        (1'b0),          // GMII发送错误信号，未使用
        // outputs
        .rgmii_tx_clk      (rgmii_tx_clk),
        .rgmii_txd         (rgmii_txd),
        .rgmii_tx_ctl      (rgmii_tx_ctl)
    );

    //* Step 4: Instantiate PHY register configuration module
    phy_reg_config #(
        .SPEED       (ETHERNET_SPEED),  // 以太网速度参数
        .MODULE_CLK  (50_000_000),      // 模块时钟频率，50MHz
        .MDC_CLK     (2_000),           // MDC总线时钟频率，2kHz
        .REG2CONFIG  (2)                // 配置寄存器个数
    ) phy_reg_config_inst(
        // inputs
        .clk            (clk_phy),
        .rst_n          (1'b0),         //* 可将此处置零以停用配置模块
        // outputs
        .read_data      (phy_read_data),
        .phy_config_done(phy_config_done),
        .mdc            (mdc),
        .mdio           (mdio)
    );
endmodule
