`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/24 17:29:35
// Design Name: Ethernet IP
// Module Name: ip_checksum_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for the IP checksum module
// 
// Dependencies: ip_checksum.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ip_checksum_tb(

    );
    // Testbench signals
    reg [3:0] version;
    reg [3:0] ihl;
    reg [7:0] tos;
    reg [15:0] total_length;
    reg [15:0] identification;
    reg [2:0] flags;
    reg [13:0] fragment_offset;
    reg [7:0] ttl;
    reg [7:0] protocol;
    reg [15:0] header_checksum;
    reg [31:0] source_ip;
    reg [31:0] dest_ip;

    wire [15:0] ip_checksum_result;

    // Instantiate the IP checksum module
    ip_checksum ip_checksum_inst (
        .version            (version),
        .ihl                (ihl),
        .tos                (tos),
        .total_length       (total_length),
        .identification     (identification),
        .flags              (flags),
        .fragment_offset    (fragment_offset),
        .ttl                (ttl),
        .protocol           (protocol),
        .header_checksum    (header_checksum),
        .source_ip          (source_ip),
        .dest_ip            (dest_ip),
        .ip_checksum_result (ip_checksum_result)
    );

    // Testbench stimulus
    initial begin
        // Initialize inputs
        #200;
        version = 4'b0100;                  // IPv4
        ihl = 4'b0101;                      // Header length of 20 bytes
        tos = 8'b00000000;                  // Default TOS
        total_length = 16'h0033;            // Total length of 51 bytes
        identification = 16'd0;             // Example identification
        flags = 3'b000;                     // No flags set
        fragment_offset = 14'd0;            // No fragmentation
        ttl = 8'd64;                        // Default TTL
        protocol = 8'd17;                   // UDP protocol
        header_checksum = 16'd0;            // Initial checksum, not used in calculation
        source_ip = 32'hC0A80002;           // Source IP: 192.168.0.2
        dest_ip = 32'hC0A80003;             // Destination IP: 192.168.0.3

        #200;
        $finish;                            // End simulation after 200 time units
    end
endmodule
