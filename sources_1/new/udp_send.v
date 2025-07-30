`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/26 16:14:48
// Design Name: Ethernet UDP/IP Send Logic
// Module Name: udp_send
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 
// 以太网UDP/IP发送逻辑模块，以状态机的模式接收输入UDP/IP数据包头，用户数据由FIFO读取，以GMII接口输出
//
// Dependencies: 
// 1. ethernet_dcfifo.v - 用于用户数据的读写操作
// 2. crc32_d8.v - 用于MAC帧的CRC32校验
// 3. ip_checksum.v - 用于IP头部的校验和计算
//
// Revision:
// [2025/07/26] Revision 0.01 - File Created
// Additional Comments:
// 1. 用户发送数据时，需将需要发送的数据写入FIFO，给出需要发送的数据长度data_length，随后产生发送启动信号tx_start
// 2. 模块会在接收到tx_start信号后，开始发送数据，发送完成后会产生发送完成信号tx_done
// 3. 在每个发送状态下，均设置一计数器，用于在相同状态下的不同时刻发送不同数据帧
// 4. 所有输入输出端口均先进行寄存
//!5. 该模块输出tx_done信号总会在发送数据的最后一位时（即CRC32校验的最后一个字节）有效一周期，而非发送结束后的一周期内有效
//////////////////////////////////////////////////////////////////////////////////


module udp_send(
    input        clk_125m,           // 125MHz模块工作时钟信号
    input        reset_n,            // 复位信号，低电平有效

    input [47:0] des_mac,            // 6字节目的MAC地址
    input [47:0] src_mac,            // 6字节源MAC地址（FPGA地址）
    input [15:0] des_udp_port,       // 2字节目的UDP端口号
    input [15:0] src_udp_port,       // 2字节源UDP端口号
    input [31:0] des_ip,             // 4字节目的IP地址
    input [31:0] src_ip,             // 4字节源IP地址
    input [15:0] data_length,        // 用户数据长度（不包含任何报头）

    input  [7:0] fifo_write_data,    // FIFO写入数据
    input        fifo_write_request, // FIFO写请求信号
    input        fifo_write_clk,     // FIFO写时钟信号
    input        fifo_write_aclr,    // FIFO写异步清除信号

    output           gmii_tx_clk,        // GMII发送时钟信号
    output reg [7:0] gmii_txd,           // GMII发送数据
    output reg       gmii_tx_en,         // GMII发送使能信号
    output reg       tx_done,            // 发送完成信号
    output [11:0]    fifo_write_usage    // FIFO写入使用率
    );

    //* Step 1. 固定字段声明 Fixed Fields Declaration
    reg tx_start;                                           // 发送启动信号，
                                                            // 由于该信号可能因为模块内部信号而改变，
                                                            // 因此不作为输入端口

    parameter [55:0] MAC_PREAMBLE = 56'h5555_5555_5555_55;  // 以太网前导码
    parameter [7:0] MAC_SFD = 8'hd5;                        // MAC帧起始定界符
    parameter [15:0] MAC_FRAME_TYPE = 16'h08_00;            // MAC帧长度/类型字段，表示上层协议为IP协议

    parameter [3:0] IP_VERSION = 4'h4;                      // IP版本号，IPv4
    parameter [3:0] IP_HEADER_LENGTH = 4'h5;                // IP头部长度，单位为4字节，即20字节总长
    parameter [7:0] IP_TOS = 8'h00;                         // IP服务类型，通常为0
    parameter [15:0] IP_ID = 16'h0000;                      // IP标识符，通常为0
    parameter [2:0] IP_FLAGS = 3'b000;                      // IP标志位，通常为0
    parameter [12:0] IP_FRAGMENT_OFFSET = 13'h0000;         // IP分段偏移，通常为0
    parameter [7:0] IP_TTL = 8'h40;                         // IP生存时间，通常为64
    parameter [7:0] IP_PROTOCOL = 8'h11;                    // IP上层协议，UDP协议为17

    //* Step 2. 输入输出信号寄存 Input & Output Signal Register
    reg [47:0] des_mac_reg;            // 6字节目的MAC地址输入寄存器
    reg [47:0] src_mac_reg;            // 6字节源MAC地址（FPGA地址）输入寄存器
    reg [15:0] des_udp_port_reg;       // 2字节目的UDP端口号输入寄存器
    reg [15:0] src_udp_port_reg;       // 2字节源UDP端口号输入寄存器
    reg [31:0] des_ip_reg;             // 4字节目的IP地址输入寄存器
    reg [31:0] src_ip_reg;             // 4字节源IP地址输入寄存器
    reg [15:0] data_length_reg;        // 用户数据长度（不包含任何报头）输入寄存器

    reg [7:0] gmii_txd_reg;            // GMII发送数据输出寄存器
    reg       gmii_tx_en_reg;          // GMII发送使能信号输出寄存器
    reg       tx_done_reg;             // 发送完成信号输出寄存器

    always @(posedge clk_125m)
        if (tx_start) begin
            des_mac_reg <= des_mac;
            src_mac_reg <= src_mac;
            des_udp_port_reg <= des_udp_port;
            src_udp_port_reg <= src_udp_port;
            des_ip_reg <= des_ip;
            src_ip_reg <= src_ip;
            data_length_reg <= data_length;
        end

    always @(posedge clk_125m) begin
        gmii_txd <= gmii_txd_reg;
        gmii_tx_en <= gmii_tx_en_reg;
        tx_done <= tx_done_reg;
    end

    //* Step 3. 实例化FIFO Instantiate FIFO for user data
    wire [7:0] fifo_read_data;      // FIFO读取数据
    reg fifo_read_request;          // FIFO读请求信号
    wire [11:0] fifo_read_usage;    // FIFO读取使用率

    ethernet_dcfifo ethernet_dcfifo_inst(
        // input
        .rst            (fifo_write_aclr),      // FIFO写异步清除信号
        .wr_clk         (fifo_write_clk),       // FIFO写时钟信号
        .rd_clk         (clk_125m),             // FIFO读时钟信号
        .din            (fifo_write_data),      // FIFO写入数据
        .wr_en          (fifo_write_request),   // FIFO写请求信号
        .rd_en          (fifo_read_request),    // FIFO读请求信号
        // output
        .dout           (fifo_read_data),       // FIFO读取数据
        .full           (),                     // FIFO满信号
        .empty          (),                     // FIFO空信号
        .rd_data_count  (fifo_read_usage),      // FIFO读取使用率
        .wr_data_count  (fifo_write_usage),     // FIFO写入使用率
        .wr_rst_busy    (),                     // FIFO写复位忙信号
        .rd_rst_busy    ()                      // FIFO读复位忙信号
    );

    //* Step 4. 对发送信号tx_start单独设置状态机 State Machine for tx_start Signal
    localparam [3:0] TX_START_IDLE = 4'b0001;          // 空闲状态
    localparam [3:0] TX_START_SEND = 4'b0010;          // 发送有效状态
    localparam [3:0] TX_START_WAIT = 4'b0100;          // 发送完成等待延时状态
    localparam [3:0] TX_START_DONE = 4'b1000;          // 发送完成过渡状态

    reg [3:0] tx_start_state;                          // 发送信号当前状态
    reg [7:0] tx_start_delay_cnt;                      // 延时计数器，用于发送完成状态的延时

    always @(posedge clk_125m or negedge reset_n)
        if (!reset_n) begin
            tx_start_state <= TX_START_IDLE;           // 复位时进入空闲状态
            tx_start <= 1'b0;                          // 发送信号清零
            tx_start_delay_cnt <= 8'b0;                // 延时计数器清零
        end
        else begin
            case (tx_start_state)
                TX_START_IDLE:
                    if (fifo_read_usage >= data_length) begin   // 如果已经从FIFO中读取到足够长度的数据
                        tx_start <= 1'b1;                       // 发送信号置为1
                        tx_start_state <= TX_START_SEND;        // 进入发送状态
                    end
                    else
                        tx_start <= 1'b0;                       // 发送信号清零，保持在空闲状态

                TX_START_SEND: begin
                    tx_start <= 1'b0;                           // 发送信号仅在开始发送时产生一次脉冲
                    if (tx_done)
                        tx_start_state <= TX_START_WAIT;        // 进入发送完成等待状态
                end

                TX_START_WAIT:
                    if (tx_start_delay_cnt == 8'd255) begin
                        tx_start_state <= TX_START_DONE;        // 延时计数器到达最大值，进入发送完成过渡状态
                        tx_start_delay_cnt <= 8'b0;             // 重置延时计数器
                    end
                    else
                        tx_start_delay_cnt <= tx_start_delay_cnt + 1'b1; // 延时计数器递增，状态保持不变

                TX_START_DONE:
                    tx_start_state <= TX_START_IDLE;            // 发送完成后回到空闲状态
            endcase
        end
    
    //* Step 5. IP报头多路选择准备以及ip_checksum.v实例化 IP Checksum Module & IP Header Multiplexer
    wire [15:0] ip_checksum;            // IP头部校验和结果
    reg [31:0] ip_header [4:0];         // IP头部寄存器数组，5个字寄存器
    wire [15:0] ip_total_length;        // IP头部总长度

    assign ip_total_length = data_length_reg + 8'd28; // IP头部总长度 = 用户数据长度 + IP头部长度 + UDP头部长度
    // 尽量避免黏附逻辑

    always @(posedge clk_125m) begin
        ip_header[0][31:16] <= {IP_VERSION, IP_HEADER_LENGTH, IP_TOS};      // IP版本号、头部长度、服务类型
        ip_header[0][15:0] <= ip_total_length;                              // 总长度 = 用户数据长度 + IP头部长度 + UDP头部长度
        ip_header[1][31:0] <= {IP_ID, IP_FLAGS, IP_FRAGMENT_OFFSET};        // 标识、标志位、分段偏移
        ip_header[2][31:24] <= IP_TTL;                                      // 生存时间
        ip_header[2][23:16] <= IP_PROTOCOL;                                 // 上层协议
        ip_header[2][15:0] <= ip_checksum;                                  // IP头部校验和
        ip_header[3][31:0] <= src_ip_reg;                                   // 源IP地址
        ip_header[4][31:0] <= des_ip_reg;                                   // 目的IP地址
    end

    // Instantiate ip_checksum module
    ip_checksum ip_checksum_inst(
        .version            (IP_VERSION),                // IP版本号
        .ihl                (IP_HEADER_LENGTH),          // IP头部长度
        .tos                (IP_TOS),                    // 服务类型
        .total_length       (ip_total_length),           // 总长度
        .identification     (IP_ID),                     // 标识
        .flags              (IP_FLAGS),                  // 标志
        .fragment_offset    (IP_FRAGMENT_OFFSET),        // 分段偏移
        .ttl                (IP_TTL),                    // 生存时间
        .protocol           (IP_PROTOCOL),               // 上层协议
        .header_checksum    (16'h0000),                  // 头部校验和
        .source_ip          (src_ip_reg),                // 源IP地址
        .dest_ip            (des_ip_reg),                // 目的IP地址
        .ip_checksum_result (ip_checksum)                // IP校验和结果输出
    );

    //* Step 6. UDP报头多路选择准备 UDP Header Multiplexer
    reg [31:0] udp_header [1:0];         // UDP头部寄存器数组，2个字（8字节）寄存器
    wire [15:0] udp_total_length;        // UDP头部总长度

    assign udp_total_length = data_length_reg + 8'd8; // UDP头部总长度 = 用户数据长度 + UDP头部长度
    // 尽量避免黏附逻辑

    always @(posedge clk_125m) begin
        udp_header[0][31:16] <= src_udp_port_reg;         // 源UDP端口号
        udp_header[0][15:0] <= des_udp_port_reg;          // 目的UDP端口号
        udp_header[1][31:16] <= udp_total_length;         // UDP头部和数据部分的总长度
        udp_header[1][15:0] <= 16'h0000;                  // UDP头部校验和，忽略
    end

    //* Step 7. CRC32校验模块实例化 CRC32 Checksum Module Instantiation
    wire crc_reset_n;                // CRC复位信号
    wire [31:0] crc_result;          // CRC校验结果
    reg crc_en;                      // CRC使能信号

    crc32_d8 crc32_d8_inst(
        .clk            (clk_125m),          // 时钟信号
        .reset_n        (crc_reset_n),       // 复位信号
        .data_in        (gmii_txd_reg),      // 输入数据
        .crc_init       (1'b0),              // CRC初始化信号，通常为0
        .crc_en         (crc_en),            // CRC使能信号
        .crc_result     (crc_result)         // CRC校验结果输出
    );
    //? 该模块输入数据被按位反转，因此最终输出CRC32校验码会按字节反转
    //? 如果不希望校验码反转（目前还不是很清楚具体以太网到底要怎么传输）
    //? 只需要更改crc32_d8.v中的data_reversed赋值方式即可

    //* Step 8. 状态机实现 State Machine Implementation
    reg [9:0] send_state;             // 发送状态寄存器

    reg [2:0] cnt_mac_header;         // 发送MAC前导码（8字节）计数器
    reg [2:0] cnt_mac_des;            // 发送目的MAC地址（6字节）计数器
    reg [2:0] cnt_mac_src;            // 发送源MAC地址（6字节）计数器
    reg       cnt_mac_type;           // 发送MAC帧类型（2字节）计数器
    reg [4:0] cnt_ip_header;          // 发送IP头部（20字节）计数器
    reg [2:0] cnt_udp_header;         // 发送UDP头部（8字节）计数器
    reg [11:0] cnt_user_data;         // 发送用户数据计数器
    reg [1:0] cnt_crc;                // 发送CRC校验（4字节）计数器

    // 状态机状态定义，采用独热码编码
    localparam [8:0] IDLE = 9'b000000001;                   // 空闲状态
    localparam [8:0] SEND_MAC_HEADER = 9'b000000010;        // 发送前导码状态
    localparam [8:0] SEND_MAC_DES = 9'b000000100;           // 发送目的MAC地址状态
    localparam [8:0] SEND_MAC_SRC = 9'b000001000;           // 发送源MAC地址状态
    localparam [8:0] SEND_MAC_TYPE = 9'b000010000;          // 发送MAC帧类型状态
    localparam [8:0] SEND_IP_HEADER = 9'b000100000;         // 发送IP头部状态
    localparam [8:0] SEND_UDP_HEADER = 9'b001000000;        // 发送UDP头部状态
    localparam [8:0] SEND_USER_DATA = 9'b010000000;         // 发送用户数据状态
    localparam [8:0] SEND_CRC = 9'b100000000;               // 发送CRC状态

    // CRC32复位信号逻辑
    assign crc_reset_n = !(send_state == IDLE);

    always @(posedge clk_125m or negedge reset_n)
        if (!reset_n) begin
            send_state <= IDLE;                             // 复位时进入空闲状态

            cnt_mac_header <= 0;
            cnt_mac_des <= 0;
            cnt_mac_src <= 0;
            cnt_mac_type <= 0;
            cnt_ip_header <= 0;
            cnt_udp_header <= 0;
            cnt_user_data <= 0;
            cnt_crc <= 0;                                   // 各类计数器清零

            gmii_txd_reg <= 8'd0;                           // 输出GMII发送数据寄存器清零
            gmii_tx_en_reg <= 1'b0;                         // 输出GMII发送使能信号寄存器清零

            fifo_read_request <= 1'b0;                      // FIFO读请求信号清零
            tx_done_reg <= 1'b0;                            // 发送完成信号清零
            crc_en <= 1'b0;                                 // CRC使能信号清零
        end
        else
            case (send_state)
                IDLE: begin
                    gmii_tx_en_reg <= 1'b0;                 // 在空闲状态下，GMII发送使能信号清零
                    tx_done_reg <= 1'b0;                    // 发送完成信号清零
                    if (tx_start)
                        send_state <= SEND_MAC_HEADER;      // 如果接收到发送启动信号，进入发送MAC头部前导码状态
                end

                SEND_MAC_HEADER: begin
                    gmii_tx_en_reg <= 1'b1;                 // 发送使能信号置为1

                    if (cnt_mac_header >= 7) begin
                        send_state <= SEND_MAC_DES;         // 如果发送前导码计数器达到8字节，进入发送目的MAC地址状态
                        cnt_mac_header <= 0;                // 清零计数器
                    end
                    else
                        cnt_mac_header <= cnt_mac_header + 1'b1;// 前导码计数器递增
                    
                    case (cnt_mac_header)
                        0: gmii_txd_reg <= MAC_PREAMBLE[55:48]; // 发送前导码的第1字节
                        1: gmii_txd_reg <= MAC_PREAMBLE[47:40]; // 发送前导码的第2字节
                        2: gmii_txd_reg <= MAC_PREAMBLE[39:32]; // 发送前导码的第3字节
                        3: gmii_txd_reg <= MAC_PREAMBLE[31:24]; // 发送前导码的第4字节
                        4: gmii_txd_reg <= MAC_PREAMBLE[23:16]; // 发送前导码的第5字节
                        5: gmii_txd_reg <= MAC_PREAMBLE[15:8];  // 发送前导码的第6字节
                        6: gmii_txd_reg <= MAC_PREAMBLE[7:0];   // 发送前导码的第7字节
                        7: gmii_txd_reg <= MAC_SFD;             // 最后一个字节为SFD
                        default: gmii_txd_reg <= 8'h55;
                    endcase
                end

                SEND_MAC_DES: begin
                    crc_en <= 1'b1;                         // 使能CRC计算
                    /*注意：crc32_d8.v模块的输入数据只有8位，因此该模块将不断接收输入数据，
                    对CRC校验码进行迭代更新，直到使能信号无效
                    因此，CRC32校验码的计算应该在gmii_txd_reg这一输出端口开始正式输出MAC帧时便开始计算，
                    即发送完前导码后开始计算，故在这里开始使能
                    而crc32_d8.v模块使用与本模块相同的时钟，保证了输入数据不会被重复计算，因此直接使能有效即可*/

                    if (cnt_mac_des >= 5) begin
                        send_state <= SEND_MAC_SRC;         // 如果发送目的MAC地址计数器达到6字节，进入发送源MAC地址状态
                        cnt_mac_des <= 0;                   // 清零计数器
                    end
                    else
                        cnt_mac_des <= cnt_mac_des + 1'b1;  // 目的MAC地址计数器递增
                    
                    case (cnt_mac_des)
                        0: gmii_txd_reg <= des_mac_reg[47:40]; // 发送目的MAC地址的第1字节
                        1: gmii_txd_reg <= des_mac_reg[39:32]; // 发送目的MAC地址的第2字节
                        2: gmii_txd_reg <= des_mac_reg[31:24]; // 发送目的MAC地址的第3字节
                        3: gmii_txd_reg <= des_mac_reg[23:16]; // 发送目的MAC地址的第4字节
                        4: gmii_txd_reg <= des_mac_reg[15:8];  // 发送目的MAC地址的第5字节
                        5: gmii_txd_reg <= des_mac_reg[7:0];   // 发送目的MAC地址的第6字节
                        default: gmii_txd_reg <= 8'hff;        // 默认值为ff，即广播地址
                    endcase                  
                end

                SEND_MAC_SRC: begin
                    if (cnt_mac_src >= 5) begin
                        send_state <= SEND_MAC_TYPE;    // 如果发送源MAC地址计数器达到6字节，进入发送MAC帧类型状态
                        cnt_mac_src <= 0;               // 清零计数器
                    end
                    else
                        cnt_mac_src <= cnt_mac_src + 1'b1;      // 源MAC地址计数器递增
                    
                    case (cnt_mac_src)
                        0: gmii_txd_reg <= src_mac_reg[47:40];  // 发送源MAC地址的第1字节
                        1: gmii_txd_reg <= src_mac_reg[39:32];  // 发送源MAC地址的第2字节
                        2: gmii_txd_reg <= src_mac_reg[31:24];  // 发送源MAC地址的第3字节
                        3: gmii_txd_reg <= src_mac_reg[23:16];  // 发送源MAC地址的第4字节
                        4: gmii_txd_reg <= src_mac_reg[15:8];   // 发送源MAC地址的第5字节
                        5: gmii_txd_reg <= src_mac_reg[7:0];    // 发送源MAC地址的第6字节
                        default: gmii_txd_reg <= 8'hff;         // 默认值为ff
                    endcase
                end

                SEND_MAC_TYPE: begin
                    if (cnt_mac_type >= 1) begin
                        send_state <= SEND_IP_HEADER;        // 如果发送MAC帧类型计数器达到2字节，进入发送IP头部状态
                        cnt_mac_type <= 0;                   // 清零计数器
                    end
                    else
                        cnt_mac_type <= cnt_mac_type + 1'b1; // MAC帧类型计数器递增

                    case (cnt_mac_type)
                        0: gmii_txd_reg <= MAC_FRAME_TYPE[15:8]; // 发送MAC帧类型的第1字节
                        1: gmii_txd_reg <= MAC_FRAME_TYPE[7:0];  // 发送MAC帧类型的第2字节
                        default: gmii_txd_reg <= 8'hff;          // 默认值为ff
                    endcase
                end

                SEND_IP_HEADER: begin
                    if (cnt_ip_header >= 19) begin
                        send_state <= SEND_UDP_HEADER;          // 如果发送IP头部计数器达到20字节，进入发送UDP头部状态
                        cnt_ip_header <= 0;                     // 清零计数器
                    end
                    else
                        cnt_ip_header <= cnt_ip_header + 1'b1;  // IP头部计数器递增
                    
                    case (cnt_ip_header)
                        0: gmii_txd_reg <= ip_header[0][31:24]; // 发送IP头部的第1字节
                        1: gmii_txd_reg <= ip_header[0][23:16]; // 发送IP头部的第2字节
                        2: gmii_txd_reg <= ip_header[0][15:8];  // 发送IP头部的第3字节
                        3: gmii_txd_reg <= ip_header[0][7:0];   // 发送IP头部的第4字节
                        4: gmii_txd_reg <= ip_header[1][31:24]; // 发送IP头部的第5字节
                        5: gmii_txd_reg <= ip_header[1][23:16]; // 发送IP头部的第6字节
                        6: gmii_txd_reg <= ip_header[1][15:8];  // 发送IP头部的第7字节
                        7: gmii_txd_reg <= ip_header[1][7:0];   // 发送IP头部的第8字节
                        8: gmii_txd_reg <= ip_header[2][31:24]; // 发送IP头部的第9字节
                        9: gmii_txd_reg <= ip_header[2][23:16]; // 发送IP头部的第10字节
                        10: gmii_txd_reg <= ip_header[2][15:8]; // 发送IP头部的第11字节
                        11: gmii_txd_reg <= ip_header[2][7:0];  // 发送IP头部的第12字节
                        12: gmii_txd_reg <= ip_header[3][31:24];// 发送IP头部的第13字节
                        13: gmii_txd_reg <= ip_header[3][23:16];// 发送IP头部的第14字节
                        14: gmii_txd_reg <= ip_header[3][15:8]; // 发送IP头部的第15字节
                        15: gmii_txd_reg <= ip_header[3][7:0];  // 发送IP头部的第16字节
                        16: gmii_txd_reg <= ip_header[4][31:24];// 发送IP头部的第17字节
                        17: gmii_txd_reg <= ip_header[4][23:16];// 发送IP头部的第18字节
                        18: gmii_txd_reg <= ip_header[4][15:8]; // 发送IP头部的第19字节
                        19: gmii_txd_reg <= ip_header[4][7:0];  // 发送IP头部的第20字节
                        default: gmii_txd_reg <= 8'hff; // 默认值为ff
                    endcase
                end

                SEND_UDP_HEADER: begin
                    if (cnt_udp_header >= 7) begin
                        send_state <= SEND_USER_DATA;   // 如果发送UDP头部计数器达到8字节，进入发送用户数据状态
                        fifo_read_request <= 1'b1;      // 此时开始读取FIFO中的用户数据
                        cnt_udp_header <= 0;            // 清零计数器
                    end
                    else
                        cnt_udp_header <= cnt_udp_header + 1'b1;

                    case (cnt_udp_header)
                        0: gmii_txd_reg <= udp_header[0][31:24]; // 发送UDP头部第1字节
                        1: gmii_txd_reg <= udp_header[0][23:16]; // 发送UDP头部第2字节
                        2: gmii_txd_reg <= udp_header[0][15:8];  // 发送UDP头部第3字节
                        3: gmii_txd_reg <= udp_header[0][7:0];   // 发送UDP头部第4字节
                        4: gmii_txd_reg <= udp_header[1][31:24]; // 发送UDP头部第5字节
                        5: gmii_txd_reg <= udp_header[1][23:16]; // 发送UDP头部第6字节
                        6: gmii_txd_reg <= udp_header[1][15:8];  // 发送UDP头部第7字节
                        7: gmii_txd_reg <= udp_header[1][7:0];   // 发送UDP头部第8字节
                        default: gmii_txd_reg <= 8'hff; // 默认值为ff
                    endcase
                end

                SEND_USER_DATA: begin
                    if (cnt_user_data >= data_length_reg - 1) begin
                        send_state <= SEND_CRC;
                        cnt_user_data <= 0;         // 清零计数器
                        fifo_read_request <= 1'b0;  // 关闭FIFO读取
                    end
                    else
                        cnt_user_data <= cnt_user_data + 1;

                    gmii_txd_reg <= fifo_read_data;     // 发送用户数据只需要在该状态下一直发送从FIFO中读取到的字节即可
                end

                SEND_CRC: begin
                    crc_en <= 1'b0;                     // 关闭CRC计算

                    if (cnt_crc >= 3) begin
                        send_state <= IDLE;             // 如果发送CRC计数器达到4字节，本次发送完毕，进入空闲状态
                        tx_done_reg <= 1'b1;            // 发送完成信号置为1
                        cnt_crc <= 0;                   // 清零计数器
                    end
                    else 
                        cnt_crc <= cnt_crc + 1'b1;      // CRC计数器递增

                    case (cnt_crc)
                        0: gmii_txd_reg <= crc_result[31:24]; // 发送CRC的第1字节
                        1: gmii_txd_reg <= crc_result[23:16]; // 发送CRC的第2字节
                        2: gmii_txd_reg <= crc_result[15:8];  // 发送CRC的第3字节
                        3: gmii_txd_reg <= crc_result[7:0];   // 发送CRC的第4字节
                        default: gmii_txd_reg <= 8'hff; // 默认值为ff
                    endcase
                end

                default: send_state <= IDLE; // 默认状态为IDLE，防止状态机进入未知状态
            endcase

    //* Step 9. GMII发送时钟输出 GMII Transmit Clock Output
    assign gmii_tx_clk = clk_125m; // 直接使用模块工作时钟作为GMII发送时钟

endmodule
