`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/26 22:32:51
// Design Name: Ethernet UDP/IP Send Logic
// Module Name: udp_send_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 以太网UDP/IP发送逻辑的测试平台
// 
// Dependencies: udp_send.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 发送23字节数据报“Hello, welcome to FPGA!”以进行验证
// Golden output 由小兵以太网测试仪生成
// 由于字节数据较少，因此直接肉眼比对即可，未编写自测试平台
//////////////////////////////////////////////////////////////////////////////////


module udp_send_tb(

    );

    //* Step 1: 输入输出端口及例化
    reg        clk_125m;            // 125MHz模块工作时钟信号
    reg        reset_n;             // 复位信号，低电平有效

    wire [47:0] des_mac;            // 6字节目的MAC地址
    wire [47:0] src_mac;            // 6字节源MAC地址（FPGA地址）
    wire [15:0] des_udp_port;       // 2字节目的UDP端口号
    wire [15:0] src_udp_port;       // 2字节源UDP端口号
    wire [31:0] des_ip;             // 4字节目的IP地址
    wire [31:0] src_ip;             // 4字节源IP地址
    wire [15:0] data_length;        // 用户数据长度（不包含任何报头）

    reg [7:0] fifo_write_data;     // FIFO写入数据
    reg       fifo_write_request;  // FIFO写请求信号
    reg       fifo_write_clk;      // FIFO写时钟信号
    reg       fifo_write_aclr;     // FIFO写异步清除信号

    wire       gmii_tx_clk;        // GMII发送时钟信号
    wire [7:0] gmii_txd;           // GMII发送数据
    wire       gmii_tx_en;         // GMII发送使能信号
    wire       tx_done;            // 发送完成信号
    wire [11:0]fifo_write_usage;   // FIFO写入使用率

    assign des_mac = 48'hC8_5B_76_DD_0B_38;     // 目的MAC地址
    assign src_mac = 48'h00_0a_35_01_fe_c0;
    assign des_udp_port = 16'd6102;             // 目的UDP端口号
    assign src_udp_port = 16'd5000;             // 源UDP端口号
    assign des_ip = 32'hc0_a8_00_03;            // 目的IP地址
    assign src_ip = 32'hc0_a8_00_02;            // 源IP地址
    assign data_length = 23;                    // 数据长度

    udp_send udp_send_inst(
        .clk_125m          (clk_125m),
        .reset_n           (reset_n),
        .des_mac           (des_mac),
        .src_mac           (src_mac),
        .des_udp_port      (des_udp_port),
        .src_udp_port      (src_udp_port),
        .des_ip            (des_ip),
        .src_ip            (src_ip),
        .data_length       (data_length),

        .fifo_write_data   (fifo_write_data),
        .fifo_write_request(fifo_write_request),
        .fifo_write_clk    (fifo_write_clk),
        .fifo_write_aclr   (fifo_write_aclr),

        .gmii_tx_clk       (gmii_tx_clk),
        .gmii_txd          (gmii_txd),
        .gmii_tx_en        (gmii_tx_en),
        .tx_done           (tx_done),
        .fifo_write_usage  (fifo_write_usage)
    );

    //* Step 2: 时钟生成
    initial begin
        clk_125m <= 1'b1;
        forever #4 clk_125m <= !clk_125m; // 125 MHz clock
    end

    initial begin
        fifo_write_clk <= 1'b1;
        forever #5 fifo_write_clk <= !fifo_write_clk; // 100 MHz clock for FIFO
    end

    //* Step 3: 激励生成
    reg [4:0] fifo_write_cnt; // FIFO写入计数器
    reg fifo_write_ctrl;      // FIFO写入控制信号
                              // 该FIFO似乎会在fifo_write_request信号有效后的12拍才开始写入数据，
                              // 因此要相应使得写入的数据延后12拍

    always @(posedge fifo_write_clk or posedge fifo_write_aclr) begin
        if (fifo_write_aclr) begin
            fifo_write_request <= 1'b0;
            fifo_write_cnt <= 5'd0; // Reset the counter
        end 
        else begin
            fifo_write_request <= 1'b1; // 请求写入FIFO

            if (fifo_write_ctrl)
                if (fifo_write_cnt >= 5'd22)
                    fifo_write_cnt <= 5'd0; // 重置计数器
                else
                    fifo_write_cnt <= fifo_write_cnt + 1'b1;

                case (fifo_write_cnt)
                    5'd0: fifo_write_data = "H";  // 'H'
                    5'd1: fifo_write_data = "e";  // 'e'
                    5'd2: fifo_write_data = "l";  // 'l'
                    5'd3: fifo_write_data = "l";  // 'l'
                    5'd4: fifo_write_data = "o";  // 'o'
                    5'd5: fifo_write_data = ",";  // ','
                    5'd6: fifo_write_data = " ";  // ' '
                    5'd7: fifo_write_data = "w";  // 'w'
                    5'd8: fifo_write_data = "e";  // 'e'
                    5'd9: fifo_write_data = "l";  // 'l'
                    5'd10: fifo_write_data = "c"; // 'c'
                    5'd11: fifo_write_data = "o"; // 'o'
                    5'd12: fifo_write_data = "m"; // 'm'
                    5'd13: fifo_write_data = "e"; // 'e'
                    5'd14: fifo_write_data = " "; // ' '
                    5'd15: fifo_write_data = "t"; // 't'
                    5'd16: fifo_write_data = "o"; // 'o'
                    5'd17: fifo_write_data = " "; // ' '
                    5'd18: fifo_write_data = "F"; // 'F'
                    5'd19: fifo_write_data = "P"; // 'P'
                    5'd20: fifo_write_data = "G"; // 'G'
                    5'd21: fifo_write_data = "A"; // 'A'
                    5'd22: fifo_write_data = "!"; // '!'
                    default: fifo_write_data = 8'h00; // Default case
                endcase
        end
    end

    //* Step 4: Simulation Starts
    initial begin
        reset_n <= 1'b0;
        fifo_write_aclr <= 1'b1;
        #1000;
        reset_n <= 1'b1;
        fifo_write_aclr <= 1'b0;
        repeat (12) @(posedge fifo_write_clk);  // FIFO写入延时，根据仿真，
                                                // 该FIFO似乎会在fifo_write_request信号有效后的12拍才开始写入数据，
                                                // 因此要相应使得写入的数据延后12拍
        fifo_write_ctrl <= 1'b1;                // 开始FIFO写入控制信号
        
        repeat (10000) @(posedge clk_125m); // Wait for some time
        $finish; // End the simulation
    end
endmodule
