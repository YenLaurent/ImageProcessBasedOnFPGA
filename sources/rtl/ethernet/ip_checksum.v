`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/24 17:03:33
// Design Name: Ethernet IP
// Module Name: ip_checksum
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: 用于以太网网络层IP协议报头部分校验和的计算模块
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 纯组合逻辑电路
// 校验和计算方法：将IP头部按16位分组求和，取反得到校验和
// 如果和的高16bit不为0，则将和的高16bit和低16bit反复相加，直到和的高16bit为0，从而获得一个16bit的值
//////////////////////////////////////////////////////////////////////////////////


module ip_checksum(
    input [3:0] version,                // IP版本号
    input [3:0] ihl,                    // IP头部长度
    input [7:0] tos,                    // 服务类型
    input [15:0] total_length,          // 总长度
    input [15:0] identification,        // 标识
    input [2:0] flags,                  // 标志
    input [12:0] fragment_offset,       // 分段偏移
    input [7:0] ttl,                    // 生存时间
    input [7:0] protocol,               // 上层协议
    input [31:0] source_ip,             // 源IP地址
    input [31:0] dest_ip,               // 目的IP地址

    output [15:0] ip_checksum_result    // IP校验和结果
    );

    wire [31:0] sum_a; // 用于存储16位分组求和的结果
    wire [31:0] sum_b;

    assign sum_a = {version, ihl, tos} + 
                    total_length + 
                    identification + 
                    {flags, fragment_offset} + 
                    {ttl, protocol} + 
                    source_ip[31:16] +
                    source_ip[15:0] +
                    dest_ip[31:16] +
                    dest_ip[15:0];
    
    assign sum_b = sum_a[31:16] + sum_a[15:0];

    assign ip_checksum_result = sum_b[31:16] ? 
                                ~(sum_b[15:0] + sum_b[31:16]) : // 若高16位在反复相加一次后仍然不为0，则再次相加
                                ~(sum_b[15:0]);                 // 否则直接取反低16位作为校验和
endmodule
