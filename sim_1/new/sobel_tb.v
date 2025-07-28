`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/06/23 21:08:32
// Design Name: Testbench for sobel.v
// Module Name: sobel_tb
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for sobel.v module.
// 
// Dependencies: sobel.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 输入中值滤波后的200*200灰度图像数据，并经过sobel滤波后输出单值图像数据
// 理论输入输出同样由外部Python脚本生成
//////////////////////////////////////////////////////////////////////////////////


module sobel_tb #(
    parameter DATA_WIDTH = 8,          // 数据位宽，即灰度数据的单个颜色通道的位宽
    parameter WIDTH = 200,             // 输入图像宽度
    parameter HEIGHT = 200,            // 输入图像高度
    parameter THRESHOLD = 128          // SOBLE算子阈值
)();

    /*--------------------------------
    ----------基本输入输出端口---------
    --------------------------------*/
    reg clk, reset_p;
    reg median_valid, median_hsync, median_vsync;
    reg [DATA_WIDTH-1:0] median;
    //
    wire sobel_valid, sobel_hsync, sobel_vsync;
    wire sobel;

    /*--------------------------------
    ----------测试变量声明-----------
    --------------------------------*/
    reg [DATA_WIDTH-1:0] median_stimulus_input [0:(WIDTH*HEIGHT-1)];      // 存储WIDTH*HEIGHT的输入median数据
    reg [DATA_WIDTH-1:0] sobel_golden_output [0:(WIDTH*HEIGHT-1)];     // 存储WIDTH*HEIGHT的理论输出sobel数据
    integer i; 
    integer error_count = 0;                // 循环变量和错误计数器

    // File names
    localparam median_input_file = "median_golden.txt";
    localparam sobel_output_file = "sobel_golden.txt";

    event read_files_done;

    /*--------------------------------
    -------------模块实例化------------
    --------------------------------*/
    sobel #(
        .DATA_WIDTH     (DATA_WIDTH),
        .THRESHOLD      (THRESHOLD)
    ) sobel_inst (
        .clk            (clk),
        .reset_p        (reset_p),
        .median         (median),
        .median_valid   (median_valid),
        .median_hsync   (median_hsync),
        .median_vsync   (median_vsync),

        .sobel          (sobel),
        .sobel_valid    (sobel_valid),
        .sobel_hsync    (sobel_hsync),
        .sobel_vsync    (sobel_vsync)
    );

    /*--------------------------------
    ------------测试向量读入-----------
    --------------------------------*/
    initial begin
        $readmemh(median_input_file, median_stimulus_input);
        $display("Finished reading %s at time %0t", median_input_file, $realtime);

        $readmemh(sobel_output_file, sobel_golden_output);
        $display("Finished reading %s at time %0t", sobel_output_file, $realtime);

        // Trigger the event to indicate that all files have been read
        repeat (2) @(posedge clk); // Ensure this happens on a clock edge
        -> read_files_done;
    end

    /*--------------------------------
    --------------正式测试-------------
    --------------------------------*/
    initial begin               // 10ns周期时钟，频率为100MHz
        clk <= 1'b0;
        forever #5 clk <= ~clk;
    end

    initial begin
        reset_p <= 1'b1;                // 复位信号初始为高
        median_valid <= 1'b0;           // 此时将输出控制信号均置为无效
        median_hsync <= 1'b0;
        median_vsync <= 1'b0;
        median <= 8'h00;                // 输入数据信号无效

        @(read_files_done);             // 等待读取文件结束事件触发
        repeat (10) @(posedge clk);     // 等待10个时钟周期
        $display("Simulation Starts.");

        reset_p <= 1'b0;                // 释放复位信号

        @(posedge clk);
        median_valid <= 1'b1;
        median_hsync <= 1'b1;
        median_vsync <= 1'b1;

        for (i=0; i<=((WIDTH*HEIGHT-1)+4); i=i+1) begin
            if (i <= (WIDTH*HEIGHT-1)) begin
                median <= median_stimulus_input[i];
            end

            if (sobel_valid) begin
                if (sobel !== sobel_golden_output[i-4][0]) begin
                    $display("@%0t: Error at index %0d | Input Median = %h | Expected Output = %h | Real Output = %h",
                             $realtime, i-4, median_stimulus_input[i-4], sobel_golden_output[i-4], sobel);
                    error_count <= error_count + 1;     // 错误计数器
                end
                else begin
                    $display("@%0t: Succeed at index %0d | Input Median = %h | Expected Output = %h | Real Output = %h",
                            $realtime, i-4, median_stimulus_input[i-4], sobel_golden_output[i-4], sobel);
                end
            end

            repeat (1) @(posedge clk);
        end

        repeat (5) @(posedge clk);

        if (error_count == 0)
            $display("Test ****P A S S E D****: All outputs match the golden output!!! Cheers!!! GOOD JOB!");
        else
            $display("Test ****F A I L E D****: %0d errors found.", error_count);
        
        $finish;    // 结束仿真
    end
endmodule
