`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Laurent
// 
// Create Date: 2025/06/21 21:36:14
// Design Name: Testbench for gray_through_median_filter.v
// Module Name: gray_through_median_filter_tb
// Project Name: ImageProcess
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for gray_through_median_filter.v module.
// 
// Dependencies: gray_through_median_filter.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: 输入灰度模块输出的200*200灰度图像数据，并经过中值滤波后输出
// 理论输入输出同样由外部Python脚本生成
//////////////////////////////////////////////////////////////////////////////////


module gray_through_median_filter_tb #(
    parameter DATA_WIDTH = 8,          // 数据位宽，即灰度数据的单个颜色通道的位宽
    parameter WIDTH = 200,             // 输入图像宽度
    parameter HEIGHT = 200             // 输入图像高度
)();

    /*--------------------------------
    ----------基本输入输出端口---------
    --------------------------------*/
    reg clk, rst_p;
    reg gray_valid, gray_hsync, gray_vsync;
    reg [DATA_WIDTH-1:0] gray;
    //
    wire median_valid, median_hsync, median_vsync;
    wire [DATA_WIDTH-1:0] median_out;

    /*--------------------------------
    ----------测试变量声明-----------
    --------------------------------*/
    reg [DATA_WIDTH-1:0] gray_stimulus_input [0:(WIDTH*HEIGHT-1)];      // 存储WIDTH*HEIGHT的输入gray数据
    reg [DATA_WIDTH-1:0] median_golden_output [0:(WIDTH*HEIGHT-1)];     // 存储WIDTH*HEIGHT的理论输出median_out数据
    integer i; 
    integer error_count = 0;                // 循环变量和错误计数器

    // File names
    localparam gray_input_file = "gray_golden.txt";
    localparam median_output_file = "median_golden.txt";

    event read_files_done;

    /*--------------------------------
    -------------模块实例化------------
    --------------------------------*/
    gray_through_median_filter #(
        .DATA_WIDTH (DATA_WIDTH)
    ) gray_through_median_filter_inst(
        .clk                (clk),
        .rst_p              (rst_p),
        .gray_valid         (gray_valid),
        .gray_hsync         (gray_hsync),
        .gray_vsync         (gray_vsync),
        .gray               (gray),

        .median_valid       (median_valid),
        .median_hsync       (median_hsync),
        .median_vsync       (median_vsync),
        .median_out         (median_out)
    );

    /*--------------------------------
    ------------测试向量读入-----------
    --------------------------------*/
    initial begin
        $readmemh(gray_input_file, gray_stimulus_input);
        $display("Finished reading %s at time %0t", gray_input_file, $realtime);

        $readmemh(median_output_file, median_golden_output);
        $display("Finished reading %s at time %0t", median_output_file, $realtime);

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
        rst_p <= 1'b1;              // 复位信号初始为高
        gray_valid <= 1'b0;         // 此时将输出控制信号均置为无效
        gray_hsync <= 1'b0;
        gray_vsync <= 1'b0;
        gray <= 8'h00;              // 输入数据信号无效

        @(read_files_done);         // 等待读取文件结束事件触发
        repeat (10) @(posedge clk); // 等待10个时钟周期
        $display("Simulation Starts.");

        rst_p <= 1'b0;              // 释放复位信号

        @(posedge clk);
        gray_valid <= 1'b1;
        gray_hsync <= 1'b1;
        gray_vsync <= 1'b1;       

        for (i=0; i<=((WIDTH*HEIGHT-1)+5); i=i+1) begin
            if (i <= (WIDTH*HEIGHT-1)) begin
                gray <= gray_stimulus_input[i];
            end

            if (median_valid) begin
                if (median_out !== median_golden_output[i-5]) begin     
                // 注意在中值滤波模块中输出与输入间隔5个时钟延迟，因此当median_out第一次有效时已经是5次循环以后了
                // 因此需要将i-5作为索引，而不是i-1
                    $display("@%0t: Error at index %0d | Input Gray = %h | Expected Output = %h | Real Output = %h", 
                             $realtime, i-5, gray_stimulus_input[i-5], median_golden_output[i-5], median_out);
                    error_count <= error_count + 1;     // 错误计数器
                end
                else begin
                    $display("@%0t: Succeed at index %0d | Input Gray = %h | Expected Output = %h | Real Output = %h", 
                            $realtime, i-5, gray_stimulus_input[i-5], median_golden_output[i-5], median_out);
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
