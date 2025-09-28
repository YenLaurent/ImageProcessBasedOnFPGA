`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/09/28 19:55:53
// Design Name: Sobel Threshold Adjustment
// Module Name: sobel_thres_adjust
// Project Name: Image Process
// Target Devices: Xilinx FPGA Artix-7
// Tool Versions: Vivado 2023.2
// Description: Sobel算子阈值调整模块，可通过板载按键S3、S2调整阈值大小
// 
// Dependencies: None
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 说明（完全在像素域处理）：
// - 在 clk_pixel_division 域对 s2/s3 做双触发同步与去抖，得到稳定电平
// - 在同域做按下沿检测，得到单拍脉冲
// - 在同域统一更新 threshold（饱和加减），避免任何跨时钟域问题
// 参数配置
// 注意：DEBOUNCE_TICKS 需按 clk_pixel_division 的频率设置为约 10ms 的计数值。
// 例如：clk_pixel_division≈25MHz 时，10ms≈250_000；≈12MHz 时，10ms≈120_000。
//////////////////////////////////////////////////////////////////////////////////


module sobel_thres_adjust #(
    parameter [23:0] DEBOUNCE_TICKS = 24'd250_000,  // 默认按 10ms@25MHz 估算，可按需调整
    parameter [7:0] THRESH_INIT = 8'd128,           // 阈值复位初值
    parameter [7:0] THRESH_STEP = 8'd10             // 每次调节步长
    )(
    input rst_n,                // 系统复位信号，低电平有效
    input clk_pixel_division,   // 由OV5640提供的像素时钟经二分频后的时钟
    input s3,                   // 阈值设置按键，增加阈值
    input s2,                   // 阈值设置按键，减少阈值
    output reg [7:0] threshold  // sobel算子阈值
    );

    //* Step 1. 像素域：按键双触发器同步（1=未按，0=按下，低有效）
    (* ASYNC_REG = "TRUE" *) reg [1:0] s3_sync_pix;
    (* ASYNC_REG = "TRUE" *) reg [1:0] s2_sync_pix;
    always @(posedge clk_pixel_division or negedge rst_n)
        if (!rst_n) begin
            s3_sync_pix <= 2'b11;
            s2_sync_pix <= 2'b11;
        end 
        else begin
            s3_sync_pix <= {s3_sync_pix[0], s3};
            s2_sync_pix <= {s2_sync_pix[0], s2};
        end

    //* Step 2. 像素域：去抖（稳定后才更新稳定态）
    reg s3_stable_pix;          // 去抖后的稳定电平
    reg s2_stable_pix;          // 去抖后的稳定电平
    reg [23:0] s3_cnt_pix;
    reg [23:0] s2_cnt_pix;

    always @(posedge clk_pixel_division or negedge rst_n)
        if (!rst_n) begin
            s3_stable_pix <= 1'b1;
            s3_cnt_pix <= 24'd0;
            s2_stable_pix <= 1'b1;
            s2_cnt_pix <= 24'd0;
        end 
        else begin
            // S3
            if (s3_sync_pix[1] == s3_stable_pix)    // 若当前输入电平与稳定电平相同，则不计时更新
                s3_cnt_pix <= 24'd0;
            else if (s3_cnt_pix == DEBOUNCE_TICKS) begin
                s3_stable_pix <= s3_sync_pix[1];
                s3_cnt_pix <= 24'd0;
            end 
            else
                s3_cnt_pix <= s3_cnt_pix + 24'd1;

            // S2
            if (s2_sync_pix[1] == s2_stable_pix)
                s2_cnt_pix <= 24'd0;
            else if (s2_cnt_pix == DEBOUNCE_TICKS) begin
                s2_stable_pix <= s2_sync_pix[1];
                s2_cnt_pix <= 24'd0;
            end 
            else
                s2_cnt_pix <= s2_cnt_pix + 24'd1;
        end

    //* Step 3. 像素域：单击脉冲（检测按下沿：1->0）
    reg s3_stable_pix_d;
    reg s2_stable_pix_d;

    always @(posedge clk_pixel_division or negedge rst_n)
        if (!rst_n) begin
            s3_stable_pix_d <= 1'b1;
            s2_stable_pix_d <= 1'b1;
        end 
        else begin
            s3_stable_pix_d <= s3_stable_pix;
            s2_stable_pix_d <= s2_stable_pix;
        end

    wire inc_pulse_pix = (s3_stable_pix_d & ~s3_stable_pix); // S3 单击
    wire dec_pulse_pix = (s2_stable_pix_d & ~s2_stable_pix); // S2 单击

    //* Step 4. 像素域：统一更新 threshold（饱和加减，单一驱动）
    always @(posedge clk_pixel_division or negedge rst_n)
        if (!rst_n) begin
            threshold <= THRESH_INIT;
        end 
        else begin
            case ({inc_pulse_pix, dec_pulse_pix})
                2'b10: // 增加
                    threshold <= (threshold > (8'hFF - THRESH_STEP)) ? 8'hFF : (threshold + THRESH_STEP);
                2'b01: // 减少
                    threshold <= (threshold < THRESH_STEP) ? 8'h00 : (threshold - THRESH_STEP);
                default:
                    threshold <= threshold; // 保持
            endcase
        end

endmodule
