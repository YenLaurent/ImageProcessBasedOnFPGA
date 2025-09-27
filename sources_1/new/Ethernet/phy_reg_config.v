`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/28 22:38:27
// Design Name: Ethernet PHY Configuration
// Module Name: phy_reg_config
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 以太网PHY寄存器配置模块
// 
// Dependencies: mdio_transmit.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 1. 通过配置超参数，可以设置PHY的工作速度（10/100/1000Mbps）
// 2. 可配置需要写入的寄存器个数
//////////////////////////////////////////////////////////////////////////////////


module phy_reg_config #(
    parameter SPEED = 2'b10,            // 10为千兆，01为百兆，00为十兆
    parameter MODULE_CLK = 50_000_000,  // 模块时钟采用50MHz
    parameter MDC_CLK = 2_000,          // MDC总线时钟采用2kHz
    parameter REG2CONFIG = 2            // 要配置的寄存器个（次）数
    )(
    input clk,                          // 模块系统时钟
    input rst_n,                        // 复位信号，低电平有效

    output [15:0] read_data,            // 读取的寄存器数据
    output phy_config_done,             // PHY初始化完成标志
    output reg mdc = 1'b0,              // MDC时钟信号（初始化以仿真）
    inout mdio                          // MDIO数据线
    );

    //* Step 1: 例化mdio_transmit模块
    wire phy_rst_n;                     // PHY复位信号
    wire [4:0] reg_addr;
    wire [15:0] write_data;
    reg start;
    wire read;
    wire done;

    wire [21:0] reg_data;   // 高1位(读/写)+5位寄存器地址+16位寄存器数据
    reg [21:0] mdio_data;   // 高1位(读/写)+5位寄存器地址+16位寄存器数据

    assign reg_addr = mdio_data[20:16];     // 寄存器地址
    assign write_data = mdio_data[15:0];    // 写入数据
    assign read = mdio_data[21];            // 读/写标志

    mdio_transmit mdio_tx_inst(
        .mdc        (mdc),
        .reset_n    (phy_rst_n),
        .start      (start),
        .read       (read),
        .phy_addr   (5'b00001),          
        .reg_addr   (reg_addr),
        .write_data (write_data),

        .done       (done),
        .read_data  (read_data),
        .mdio       (mdio)
    );

    //* Step 2: PHY复位逻辑
    // PHY复位信号phy_rst_n需要在配置开始前拉低至少10ms
    // 之后释放phy_rst_n，再等至少20ms后，才能开始配置PHY
    wire config_en; // 配置使能信号
    reg [24:0] cnt; // 计数器，用于延时

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            cnt <= 25'd0;
        else if (cnt < 25'd1_500_000)                   // 系统时钟为50MHz，则此处相当于计时30ms
            cnt <= cnt + 1'b1;

    assign phy_rst_n = (cnt > 25'd500_000);             // PHY复位信号，拉低10ms后释放
    assign config_en = (cnt > 25'd1_500_000 - 1'b1);    // 配置使能信号，30ms后有效

    //* Step 3: 配置PHY寄存器的状态机
    reg state;              // 状态寄存器，0：开始写入PHY寄存器，1：写入完成
                            // 较为简单，故不设状态编码
    reg [2:0] reg_cnt = 0;  // 寄存器计数器，记录已经写入的PHY寄存器个数

    always @(negedge mdc)           // 这里需要根据mdio模块的时钟进行编写
        if (!config_en) begin
            state <= 1'b0;   
            start <= 1'b0;
            mdio_data <= reg_data;  // 初始化寄存器数据
        end
        else if (reg_cnt < REG2CONFIG)
            case (state)
                1'b0: begin                 // 开始写寄存器
                    start <= 1'b1;          // 启动MDIO传输
                    state <= 1'b1;          // 切换到写入完成状态
                    mdio_data <= reg_data;  // 准备要写入的数据
                end
                1'b1: begin                         // 写寄存器完成
                    if (done) begin                 // 检测mdio_transmit.v模块的done信号，等待写入完成
                        start <= 1'b0;              // 停止MDIO传输
                        state <= 1'b0;              // 回到开始状态
                        reg_cnt <= reg_cnt + 1'b1;  // 写入PHY寄存器计数加一
                    end
                end
            endcase
    
    assign phy_config_done = (reg_cnt == REG2CONFIG); // PHY初始化配置完成标志，当写入寄存器个数等于配置个数时有效
    
    //* Step 4: 准备要写入的寄存器数据
    // TODO: 该部分可根据实际配置需要进行修改，以适应不同PHY的寄存器配置
    // TODO: 注意reg_cnt的最大值为需要写入的寄存器个数REG2CONFIG-1
    assign reg_data = (reg_cnt == 3'd0) ? {1'b0, 5'b00000, 16'h0900} :
                      // 写入 | 寄存器地址0x00 | 数据0x0900，即取消自动协商+掉电+全双工，其余默认
                      (reg_cnt == 3'd1) ? {1'b0, 5'b00000, {2'b00, SPEED[0], 6'b000010, SPEED[1], 6'b000000}} :
                      // 写入 | 寄存器地址0x00 | 修改网卡速率+设置全双工+取消自动协商
                      {1'b0, 5'd0, 16'h1140};
                      // 默认值

    //* Step 5: MDIO时钟生成
    reg [15:0] div_cnt; // 分频计数器，用于生成MDC时钟
    
    always @(posedge clk or negedge rst_n)
        if (!rst_n) begin
            div_cnt <= 16'd0;
            mdc <= 1'b0;
        end
        else if (div_cnt >= (MODULE_CLK / MDC_CLK) / 2 - 1) begin // 根据MDC_CLK生成MDC时钟
            div_cnt <= 16'd0;
            mdc <= ~mdc;
            // 这里mdc时钟是系统工作时钟clk的25000分频
            // 即MDC时钟频率为2kHz，clk系统工作时钟为50MHz 
        end
        else
            div_cnt <= div_cnt + 1'b1;

endmodule