`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/28 18:52:56
// Design Name: Ethernet PHY Configuration
// Module Name: mdio_transmit
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 以太网PHY配置模块，负责通过MDIO接口向PHY发送配置命令和数据
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 1. 与udp_send.v模块类似，同样采用状态机来控制MDIO的传输过程
// 2. 可配置PHY地址与寄存器地址
// 3. 该总线一个时钟周期发送1 bit数据，而以太网RGMII/GMII协议一个时钟周期可发送8 bit数据
//!4. 该模块输出done信号总会在传输数据的最后一位时有效一周期，而非传输结束后的一周期内有效 
//////////////////////////////////////////////////////////////////////////////////


module mdio_transmit(
    input mdc,                  // MDIO时钟信号
    input reset_n,              // 复位信号，低有效
    input start,                // 启动信号，开始MDIO传输
    input read,                 // 读操作标志，1表示读操作，0表示写操作
    input [4:0] phy_addr,       // PHY地址
    input [4:0] reg_addr,       // 寄存器地址
    input [15:0] write_data,    // 写操作时的数据

    output reg done,            // 传输完成标志
    output reg [15:0] read_data,// 读操作时的数据
    inout mdio                  // MDIO数据线
    );

    reg mdio_o;                 // MDIO原始输出数据
    reg mdio_en;                // MDIO输出使能

    assign mdio = mdio_en ? mdio_o : 1'bz; // MDIO数据线控制，仅在使能时输出数据

    //* Step 1. 状态定义
    localparam [7:0] IDLE = 8'b00000001;        // 空闲状态
    localparam [7:0] PREAMBLE = 8'b00000010;    // 前导码
    localparam [7:0] START = 8'b00000100;       // 帧起始
    localparam [7:0] OP = 8'b00001000;          // 读写操作码
    localparam [7:0] PHY_ADDR = 8'b00010000;    // PHY地址
    localparam [7:0] REG_ADDR = 8'b00100000;    // 寄存器地址
    localparam [7:0] TA = 8'b01000000;          // MDIO信号线控制权
    localparam [7:0] WRITE_DATA = 8'b10000000;  // 写数据

    reg [7:0] state;            // 当前状态寄存器
    reg [7:0] bit_cnt;          // 位计数器，用于跟踪传输的位数

    //* Step 2. 状态机实现
    always @(negedge mdc or negedge reset_n) // 数据在MDC下降沿变化，在上升沿采样
        if (!reset_n) begin
            state <= IDLE;         // 复位时进入空闲状态
            bit_cnt <= 8'd0;       // 清除位计数器
            mdio_o <= 1'b1;        // MDIO线默认高电平   
            mdio_en <= 1'b0;       // 禁用MDIO输出
            read_data <= 16'd0;    // 清除读数据
            done <= 1'b0;          // 清除完成标志 
        end
        else
            case (state)
                IDLE: begin                 // 空闲
                    done <= 1'b0;           // 仅在初始和结束状态下需要对done, read_data, mdio_en进行赋值
                    read_data <= 16'd0;
                    mdio_o <= 1'b1;         // 该状态下mdio保持高阻，mdio_o拉高即可
                    mdio_en <= 1'b0;        // 该状态下发送使能无效

                    if (start) begin
                        state <= PREAMBLE;  // 启动传输，进入前导码状态
                        bit_cnt <= 8'd0;    // 清除计数值
                    end
                end

                PREAMBLE: begin             // 前导码，发送固定的32'b1
                    if (bit_cnt >= 31) begin
                        state <= START;     // 状态切换
                        bit_cnt <= 8'd0;    // 该状态下发送计数清零，发送完成
                    end
                    else
                        bit_cnt <= bit_cnt + 1;

                    mdio_en <= 1'b1;        // 发送有效，该赋值需要放到PREAMBLE状态下以延时1拍，根据仿真波形决定
                    mdio_o <= 1'b1;         // 前导码发送固定的32位1
                end

                START: begin                // 帧起始，发送固定的2'b01
                    if (bit_cnt >= 1) begin
                        state <= OP;
                        bit_cnt <= 8'd0;
                    end
                    else
                        bit_cnt <= bit_cnt + 1;

                    mdio_o <= (bit_cnt == 0) ? 1'b0 : 1'b1;
                end

                OP: begin                   // 操作码，发送2'b01表示写入，2'b10表示读取
                    if (bit_cnt >= 1) begin
                        state <= PHY_ADDR;
                        bit_cnt <= 8'd0;
                    end
                    else
                        bit_cnt <= bit_cnt + 1;

                    mdio_o <= (bit_cnt == 0) ? read : !read;    // read = 1'b1表示读取，反之则为写入，恰好可以这样发送
                end

                PHY_ADDR: begin             // PHY地址，5位
                    if (bit_cnt >= 4) begin
                        state <= REG_ADDR;
                        bit_cnt <= 8'd0;
                    end
                    else
                        bit_cnt <= bit_cnt + 1;
                    
                    case (bit_cnt)
                        0: mdio_o <= phy_addr[4];
                        1: mdio_o <= phy_addr[3];
                        2: mdio_o <= phy_addr[2];
                        3: mdio_o <= phy_addr[1];
                        4: mdio_o <= phy_addr[0];
                        default : mdio_o <= 1'b1;   // 默认情况
                    endcase
                end

                REG_ADDR: begin             // 寄存器地址，5位
                    if (bit_cnt >= 4) begin
                        state <= TA;
                        bit_cnt <= 8'd0;
                    end
                    else
                        bit_cnt <= bit_cnt + 1;
                    
                    case (bit_cnt)
                        0: mdio_o <= reg_addr[4];
                        1: mdio_o <= reg_addr[3];
                        2: mdio_o <= reg_addr[2];
                        3: mdio_o <= reg_addr[1];
                        4: mdio_o <= reg_addr[0];
                        default : mdio_o <= 1'b1;   // 默认情况
                    endcase
                end

                TA: begin                   // 控制权切换，2位
                    if (bit_cnt >= 1) begin
                        state <= WRITE_DATA;
                        bit_cnt <= 8'd0;
                    end
                    else
                        bit_cnt <= bit_cnt + 1;

                    mdio_o <= (bit_cnt == 0) ? !read : 1'b0;
                    mdio_en <= (bit_cnt == 0) ? !read : 1'b1;
                    // 读取状态下，mdio发送2'bz0，等待PHY驱动数据线
                    // 写入状态下，mdio发送2'b10即可
                end

                WRITE_DATA: begin           // 传输数据，16位
                    if (bit_cnt >= 15) begin
                        state <= IDLE;
                        bit_cnt <= 8'd0;
                        done <= 1'b1;       // 传输完成标志
                    end
                    else
                        bit_cnt <= bit_cnt + 1;
                    
                    if (read)   // 读取，该状态下mdio数据线此时不能被MAC驱动，只能由PHY驱动，即变成了输入端
                        read_data <= {read_data[14:0], mdio};   // 采用移位寄存器的方式读取数据
                        // 当done == 1'b1时可视为read_data填充完毕
                    else        // 写入
                        case (bit_cnt)
                            0: mdio_o <= write_data[15];
                            1: mdio_o <= write_data[14];
                            2: mdio_o <= write_data[13];
                            3: mdio_o <= write_data[12];
                            4: mdio_o <= write_data[11];
                            5: mdio_o <= write_data[10];
                            6: mdio_o <= write_data[9];
                            7: mdio_o <= write_data[8];
                            8: mdio_o <= write_data[7];
                            9: mdio_o <= write_data[6];
                            10: mdio_o <= write_data[5];
                            11: mdio_o <= write_data[4];
                            12: mdio_o <= write_data[3];
                            13: mdio_o <= write_data[2];
                            14: mdio_o <= write_data[1];
                            15: mdio_o <= write_data[0];
                            default: mdio_o <= 1'b1;
                        endcase
                end
            endcase
endmodule
