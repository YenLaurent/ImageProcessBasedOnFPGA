`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/06/01 22:02:47
// Design Name: Testbench for rgb2gray.v
// Module Name: rgb2gray_tb
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for rgb2gray.v module.
// 
// Dependencies: rgb2gray.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 输入尺寸为WIDTH*HEIGHT的RGB888图像数据，输出尺寸为200*200的灰度图像数据，
// 该输入与理论输出由外部Python脚本生成
//////////////////////////////////////////////////////////////////////////////////


module rgb2gray_tb #(
    parameter METHOD = "WEIGHT",    // 选择加权平均法
    parameter WIDTH = 200,          // 输入图像宽度
    parameter HEIGHT = 200          // 输入图像高度
)();

    /*--------------------------------
    ----------基本输入输出端口---------
    --------------------------------*/
    reg clk, rst_p;
    reg rgb_valid;
    reg rgb_hsync, rgb_vsync;
    reg [7:0] r, g, b;
    wire [7:0] gray;
    wire gray_valid;
    wire gray_hsync, gray_vsync;

    /*--------------------------------
    ------------测试变量声明-----------
    --------------------------------*/
    reg [7:0] r_stimulus_input [0:(WIDTH*HEIGHT-1)];    // 存储WIDTH*HEIGHT的输入red数据
    reg [7:0] g_stimulus_input [0:(WIDTH*HEIGHT-1)];    // 存储WIDTH*HEIGHT的输入green数据
    reg [7:0] b_stimulus_input [0:(WIDTH*HEIGHT-1)];    // 存储WIDTH*HEIGHT的输入blue数据
    reg [7:0] gray_golden_output [0:(WIDTH*HEIGHT-1)];  // 存储WIDTH*HEIGHT的理论输出gray数据
    integer i; 
    integer error_count = 0;                // 循环变量和错误计数器

    // File names
    localparam r_input_file = "r_input.txt";
    localparam g_input_file = "g_input.txt";
    localparam b_input_file = "b_input.txt";
    localparam gray_output_file = "gray_golden.txt";

    event read_files_done;

    /*--------------------------------
    -------------模块实例化------------
    --------------------------------*/
    rgb2gray #(
        .METHOD (METHOD)      // 选择加权平均法
    )   rgb2gray(
        .clk            (clk),
        .rst_p          (rst_p),
        .rgb_valid      (rgb_valid),
        .rgb_hsync      (rgb_hsync),
        .rgb_vsync      (rgb_vsync),
        .r              (r),
        .g              (g),
        .b              (b),
        .gray           (gray),
        .gray_valid     (gray_valid),
        .gray_hsync     (gray_hsync),
        .gray_vsync     (gray_vsync)
    );

    /*--------------------------------
    ------------测试向量读入-----------
    --------------------------------*/
    initial begin
        // $readmemh reads hexadecimal values from a file into a memory (array).
        // Python script outputs should be hexadecimal values, one per line,
        // without the "0x" or "h" prefix. For example:
        // FF
        // 0A
        // 1B
        // etc.
        $readmemh(r_input_file, r_stimulus_input);
        $display("Finished reading %s at time %0t", r_input_file, $realtime);

        $readmemh(g_input_file, g_stimulus_input);
        $display("Finished reading %s at time %0t", g_input_file, $realtime);

        $readmemh(b_input_file, b_stimulus_input);
        $display("Finished reading %s at time %0t", b_input_file, $realtime);

        $readmemh(gray_output_file, gray_golden_output);
        $display("Finished reading %s at time %0t", gray_output_file, $realtime);

        // Trigger the event to indicate that all files have been read
        repeat (2) @(posedge clk); // Ensure this happens on a clock edge
        -> read_files_done;
    end

    /*--------------------------------
    --------------正式测试-------------
    --------------------------------*/
    initial begin
        clk <= 1'b0;
        forever #5 clk <= ~clk;     // 10ns周期时钟，频率为100MHz
    end

    initial begin
        rst_p <= 1'b1;              // 复位信号初始为高
        rgb_valid <= 1'b0;          // Keep valid low during reset
        rgb_hsync <= 1'b0;          // Initialize sync signals
        rgb_vsync <= 1'b0;
        r <= 8'h00;
        g <= 8'h00;
        b <= 8'h00;

        @(read_files_done);         // 等待读取文件结束事件触发
        repeat (10) @(posedge clk); // 等待10个时钟周期
        $display("Simulation Starts.");

        rst_p <= 1'b0;              // 释放复位信号

        @(posedge clk);             // Wait a cycle after reset deassertion before asserting valid signals
        rgb_valid <= 1'b1;          // 输入数据有效
        rgb_hsync <= 1'b1;          // 行同步信号有效
        rgb_vsync <= 1'b1;          // 场同步信号有效

        for (i=0; i<=((WIDTH*HEIGHT-1)+1); i=i+1) begin
            if (i <= (WIDTH*HEIGHT-1)) begin
                r <= r_stimulus_input[i];   // 读取红色通道数据
                g <= g_stimulus_input[i];   // 读取绿色通道数据
                b <= b_stimulus_input[i];   // 读取蓝色通道数据
            end

            @(posedge clk);             // 等待1个时钟周期后灰度模块数据开始串行输出
            if (gray_valid) begin       // 确保输出信号有效
                if (gray !== gray_golden_output[i-1]) begin
                    $display("@%0t: Error at index %0d | Input (R=%h, G=%h, B=%h) | Expected Output %h | Real Output %h", 
                             $realtime, i-1, r_stimulus_input[i-1], g_stimulus_input[i-1], b_stimulus_input[i-1], gray_golden_output[i-1], gray);
                    error_count <= error_count + 1; // 如果输出数据与理论输出不一致，计数器加1
                end
                else begin
                    $display("@%0t: Succeed at index %0d | Input (R=%h, G=%h, B=%h) | Expected Output %h | Real Output %h", 
                             $realtime, i-1, r_stimulus_input[i-1], g_stimulus_input[i-1], b_stimulus_input[i-1], gray_golden_output[i-1], gray);
                end
            end
            else if ((i <= (WIDTH*HEIGHT-1)) & (i !== 0)) begin
                $display("@%0t: Warning at pixel index %0d: gray_valid is low when data was expected.", $realtime, i);
            end
        end

        repeat (3) @(posedge clk); // 等待3个时钟周期，确保所有数据都已处理完毕

        if (error_count == 0)
            $display("Test passed: All outputs match the golden output!!! Cheers!!! GOOD JOB!");
        else
            $display("Test failed: %0d errors found.", error_count);
        
        $finish; // 结束仿真
    end

endmodule
