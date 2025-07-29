`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UESTC
// Engineer: Yen Xu
// 
// Create Date: 2025/07/29 19:48:44
// Design Name: Ethernet Image Formatter
// Module Name: image_eth_formatter_tb
// Project Name: Image Process
// Target Devices: Xilinx Artix-7
// Tool Versions: Vivado 2023.2
// Description: Testbench for image_eth_formatter module
// 
// Dependencies: image_eth_formatter.v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module image_eth_formatter_tb(

    );

    //* Step 1: Module Instantiation
    reg clk_pixel;
    reg rst_n;
    reg valid;
    reg hsync;
    reg vsync;
    reg [7:0] pixel_data;
    wire fifo_aclr;
    wire [7:0] write_data;
    wire write_req;

    image_eth_formatter image_eth_formatter_inst (
        // inputs
        .clk_pixel      (clk_pixel),
        .rst_n          (rst_n),
        .valid          (valid),
        .hsync          (hsync),
        .vsync          (vsync),
        .pixel_data     (pixel_data),
        // outputs
        .fifo_aclr      (fifo_aclr),
        .write_data     (write_data),
        .write_req      (write_req)
    );

    //* Step 2: Clock Generation
    initial begin
        clk_pixel <= 1'b0;
        forever #10 clk_pixel <= ~clk_pixel; // 50MHz clock
    end

    //* Step 3: Testbench Initialization
    always @(posedge clk_pixel)
        if (!rst_n)
            pixel_data <= 8'h00;
        else if (hsync && valid)            // 像素数据在行同步信号有效时自加
            pixel_data <= pixel_data + 1;

    initial begin
        rst_n <= 1'b0;
        hsync <= 1'b0;
        vsync <= 1'b0;
        valid <= 1'b0;                      // 初始时所有信号无效

        repeat (10) @(posedge clk_pixel);
        rst_n <= 1'b1;
        hsync <= 1'b0;
        vsync <= 1'b1; // Set vsync high
        valid <= 1'b1; // Set valid high
        
        repeat (100) #200 hsync <= !hsync;  // Toggle hsync every 200ns, simulate lines of pixels
                                            // To see if the line_count accumulates correctly

        #200 vsync <= 1'b0;                 // Toggle vsync to simulate a new frame
        #200 vsync <= 1'b1;                 // To see if the line_count resets correctly

        repeat (100) #200 hsync <= !hsync;  // Toggle hsync every 200ns again

        $finish;                            // End simulation
    end

endmodule
