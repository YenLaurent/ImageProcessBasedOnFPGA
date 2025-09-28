`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/06/23 21:42:07
// Design Name: Testbench for image_process_top.v
// Module Name: image_process_top_tb
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for image_process_top.v module.
// 
// Dependencies: image_process_top.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 输入RGB888图像数据，经过灰度化处理、中值滤波处理、边缘检测处理后输出二值图像数据
// 理论输入输出同样由外部Python脚本生成
//////////////////////////////////////////////////////////////////////////////////


module image_process_top_tb #(
    parameter DATA_WIDTH = 8,          // 数据位宽，即灰度数据的单个颜色通道的位宽
    parameter WIDTH = 200,             // 输入图像宽度
    parameter HEIGHT = 200,            // 输入图像高度
    parameter THRESHOLD = 128,         // SOBEL算子阈值
    parameter METHOD = "WEIGHT"        // 灰度滤波办法，"AVERAGE": 平均值法，"WEIGHT": 加权平均法
)();

    /*--------------------------------
    ----------基本输入输出端口---------
    --------------------------------*/
    reg clk, rst_p;
    reg rgb_valid, rgb_hsync, rgb_vsync;
    reg [DATA_WIDTH-1:0] r, g, b;
    //
    wire sobel_valid, sobel_hsync, sobel_vsync;
    wire sobel;

    /*--------------------------------
    ----------测试变量声明-----------
    --------------------------------*/
    reg [DATA_WIDTH-1:0] r_stimulus_input [0:(WIDTH*HEIGHT-1)];     // 存储WIDTH*HEIGHT的输入red数据
    reg [DATA_WIDTH-1:0] g_stimulus_input [0:(WIDTH*HEIGHT-1)];     // 存储WIDTH*HEIGHT的输入green数据
    reg [DATA_WIDTH-1:0] b_stimulus_input [0:(WIDTH*HEIGHT-1)];     // 存储WIDTH*HEIGHT的输入blue数据
    reg [DATA_WIDTH-1:0] sobel_golden_output [0:(WIDTH*HEIGHT-1)];  // 存储WIDTH*HEIGHT的理论输出sobel数据
    integer i; 
    integer error_count = 0;                // 循环变量和错误计数器

    // File names
    localparam r_input_file = "r_input.txt";
    localparam g_input_file = "g_input.txt";
    localparam b_input_file = "b_input.txt";
    localparam sobel_output_file = "sobel_golden.txt";

    event read_files_done;

    /*--------------------------------
    -------------模块实例化------------
    --------------------------------*/
    image_process_top #(
        .DATA_WIDTH     (DATA_WIDTH),
        .THRESHOLD      (THRESHOLD),
        .METHOD         (METHOD)
    ) image_process_top_inst (
        .clk            (clk),
        .rst_p          (rst_p),
        .rgb_valid      (rgb_valid),
        .rgb_hsync      (rgb_hsync),
        .rgb_vsync      (rgb_vsync),
        .r              (r),
        .g              (g),
        .b              (b),

        .sobel          (sobel),
        .sobel_valid    (sobel_valid),
        .sobel_hsync    (sobel_hsync),
        .sobel_vsync    (sobel_vsync)
    );

    /*--------------------------------
    ------------测试向量读入-----------
    --------------------------------*/
    initial begin
        $readmemh(r_input_file, r_stimulus_input);
        $display("Finished reading %s at time %0t", r_input_file, $realtime);

        $readmemh(g_input_file, g_stimulus_input);
        $display("Finished reading %s at time %0t", g_input_file, $realtime);

        $readmemh(b_input_file, b_stimulus_input);
        $display("Finished reading %s at time %0t", b_input_file, $realtime);

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
        rst_p <= 1'b1;                  // 复位信号初始为高
        rgb_valid <= 1'b0;              // 此时将输出控制信号均置为无效
        rgb_hsync <= 1'b0;
        rgb_vsync <= 1'b0;

        r <= 8'h00;                     // 输入数据信号无效
        g <= 8'h00;
        b <= 8'h00;

        @(read_files_done);             // 等待读取文件结束事件触发
        repeat (10) @(posedge clk);     // 等待10个时钟周期
        $display("Simulation Starts.");

        rst_p <= 1'b0;                  // 释放复位信号

        @(posedge clk);
        rgb_valid <= 1'b1;
        rgb_hsync <= 1'b1;
        rgb_vsync <= 1'b1;

        for (i=0; i<=((WIDTH*HEIGHT-1)+9); i=i+1) begin // 总的流水线延时为8个时钟周期，额外多出来的一个时钟周期其实是Python脚本本身早了一个时钟周期
            if (i <= (WIDTH*HEIGHT-1)) begin
                r <= r_stimulus_input[i];
                g <= g_stimulus_input[i];
                b <= b_stimulus_input[i];
            end

            if (sobel_valid) begin
                if (sobel !== sobel_golden_output[i-9][0]) begin
                    $display("@%0t: Error at index %0d | Input (R=%h, G=%h, B=%h) | Expected Output %h | Real Output %h", 
                             $realtime, i-9, r_stimulus_input[i-9], g_stimulus_input[i-9], b_stimulus_input[i-9], sobel_golden_output[i-9][0], sobel);
                    error_count <= error_count + 1; // 如果输出数据与理论输出不一致，计数器加1
                end
                else begin
                    $display("@%0t: Succeed at index %0d | Input (R=%h, G=%h, B=%h) | Expected Output %h | Real Output %h", 
                             $realtime, i-9, r_stimulus_input[i-9], g_stimulus_input[i-9], b_stimulus_input[i-9], sobel_golden_output[i-9][0], sobel);
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
