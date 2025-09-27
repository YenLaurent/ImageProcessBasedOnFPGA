`timescale 1ns/1ns
//////////////////////////////////////////////////////////////////////////////////
// vim: ts=4 sw=4 expand tab

// THIS IS GENERATED VERILOG CODE.
// https://bues.ch/h/crcgen
// 
// This code is Public Domain.
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted.
// 
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
// SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
// RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
// USE OR PERFORMANCE OF THIS SOFTWARE.
//*输入数据被按位反转，因此最终输出CRC32校验码会按字节反转
//////////////////////////////////////////////////////////////////////////////////


module crc32_d8(
    input clk,                // 时钟信号
    input reset_n,            // 复位信号
    input [7:0] data_in,      // 输入数据
    input crc_en,             // CRC使能信号
    input crc_init,           // CRC初始化信号

    output [31:0] crc_result  // CRC校验结果输出
  	);

	parameter tp = 1;
  	reg [31:0] crc;
  	wire [31:0] crc_next;
	wire [7:0] data_reversed;

	assign data_reversed = {data_in[0], data_in[1], data_in[2], data_in[3], data_in[4], data_in[5], data_in[6], data_in[7]};
	//* 输入数据被按位反转，因此最终输出CRC32校验码会按字节反转

	assign crc_next[0] = crc[24] ^ crc[30] ^ data_reversed[0] ^ data_reversed[6];
	assign crc_next[1] = crc[24] ^ crc[25] ^ crc[30] ^ crc[31] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[2] = crc[24] ^ crc[25] ^ crc[26] ^ crc[30] ^ crc[31] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[3] = crc[25] ^ crc[26] ^ crc[27] ^ crc[31] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[3] ^ data_reversed[7];
	assign crc_next[4] = crc[24] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ data_reversed[0] ^ data_reversed[2] ^ data_reversed[3] ^ data_reversed[4] ^ data_reversed[6];
	assign crc_next[5] = crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[3] ^ data_reversed[4] ^ data_reversed[5] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[6] = crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[4] ^ data_reversed[5] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[7] = crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[31] ^ data_reversed[0] ^ data_reversed[2] ^ data_reversed[3] ^ data_reversed[5] ^ data_reversed[7];
	assign crc_next[8] = crc[0] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[3] ^ data_reversed[4];
	assign crc_next[9] = crc[1] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[4] ^ data_reversed[5];
	assign crc_next[10] = crc[2] ^ crc[24] ^ crc[26] ^ crc[27] ^ crc[29] ^ data_reversed[0] ^ data_reversed[2] ^ data_reversed[3] ^ data_reversed[5];
	assign crc_next[11] = crc[3] ^ crc[24] ^ crc[25] ^ crc[27] ^ crc[28] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[3] ^ data_reversed[4];
	assign crc_next[12] = crc[4] ^ crc[24] ^ crc[25] ^ crc[26] ^ crc[28] ^ crc[29] ^ crc[30] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[4] ^ data_reversed[5] ^ data_reversed[6];
	assign crc_next[13] = crc[5] ^ crc[25] ^ crc[26] ^ crc[27] ^ crc[29] ^ crc[30] ^ crc[31] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[3] ^ data_reversed[5] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[14] = crc[6] ^ crc[26] ^ crc[27] ^ crc[28] ^ crc[30] ^ crc[31] ^ data_reversed[2] ^ data_reversed[3] ^ data_reversed[4] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[15] = crc[7] ^ crc[27] ^ crc[28] ^ crc[29] ^ crc[31] ^ data_reversed[3] ^ data_reversed[4] ^ data_reversed[5] ^ data_reversed[7];
	assign crc_next[16] = crc[8] ^ crc[24] ^ crc[28] ^ crc[29] ^ data_reversed[0] ^ data_reversed[4] ^ data_reversed[5];
	assign crc_next[17] = crc[9] ^ crc[25] ^ crc[29] ^ crc[30] ^ data_reversed[1] ^ data_reversed[5] ^ data_reversed[6];
	assign crc_next[18] = crc[10] ^ crc[26] ^ crc[30] ^ crc[31] ^ data_reversed[2] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[19] = crc[11] ^ crc[27] ^ crc[31] ^ data_reversed[3] ^ data_reversed[7];
	assign crc_next[20] = crc[12] ^ crc[28] ^ data_reversed[4];
	assign crc_next[21] = crc[13] ^ crc[29] ^ data_reversed[5];
	assign crc_next[22] = crc[14] ^ crc[24] ^ data_reversed[0];
	assign crc_next[23] = crc[15] ^ crc[24] ^ crc[25] ^ crc[30] ^ data_reversed[0] ^ data_reversed[1] ^ data_reversed[6];
	assign crc_next[24] = crc[16] ^ crc[25] ^ crc[26] ^ crc[31] ^ data_reversed[1] ^ data_reversed[2] ^ data_reversed[7];
	assign crc_next[25] = crc[17] ^ crc[26] ^ crc[27] ^ data_reversed[2] ^ data_reversed[3];
	assign crc_next[26] = crc[18] ^ crc[24] ^ crc[27] ^ crc[28] ^ crc[30] ^ data_reversed[0] ^ data_reversed[3] ^ data_reversed[4] ^ data_reversed[6];
	assign crc_next[27] = crc[19] ^ crc[25] ^ crc[28] ^ crc[29] ^ crc[31] ^ data_reversed[1] ^ data_reversed[4] ^ data_reversed[5] ^ data_reversed[7];
	assign crc_next[28] = crc[20] ^ crc[26] ^ crc[29] ^ crc[30] ^ data_reversed[2] ^ data_reversed[5] ^ data_reversed[6];
	assign crc_next[29] = crc[21] ^ crc[27] ^ crc[30] ^ crc[31] ^ data_reversed[3] ^ data_reversed[6] ^ data_reversed[7];
	assign crc_next[30] = crc[22] ^ crc[28] ^ crc[31] ^ data_reversed[4] ^ data_reversed[7];
	assign crc_next[31] = crc[23] ^ crc[29] ^ data_reversed[5];

	always @(posedge clk)
    if (!reset_n)
      crc <= {32{1'b1}};
    else if (crc_init)
      crc <= {32{1'b1}};
    else if (crc_en)
      crc <= crc_next;

  	assign crc_result = ~{crc_next[24], crc_next[25], crc_next[26], crc_next[27], crc_next[28], crc_next[29], crc_next[30], crc_next[31],
                      	  crc[16], crc[17], crc[18], crc[19],crc[20], crc[21], crc[22], crc[23],
                      	  crc[8], crc[9], crc[10], crc[11],crc[12], crc[13], crc[14], crc[15],
                      	  crc[0], crc[1], crc[2], crc[3],crc[4], crc[5], crc[6], crc[7]};		

endmodule
