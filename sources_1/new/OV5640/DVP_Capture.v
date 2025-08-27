module DVP_Capture(
    input  wire        Rst_p,
    input  wire        PCLK,
    input  wire        Vsync,
    input  wire        Href,
    input  wire [7:0]  Data,

    output reg         ImageState,
    output reg         DataValid,
    output reg [15:0]  DataPixel,
    output reg         DataHs,
    output reg         DataVs,
    output reg [11:0]  Xaddr,
    output reg [11:0]  Yaddr
);

    reg DataHs_reg;
    // 寄存输入信号
    reg r_Vsync, r_Href;
    reg [7:0] r_Data;
    always @(posedge PCLK) begin
        r_Vsync <= Vsync;
        r_Href  <= Href;
        r_Data  <= Data;
        DataHs  <= DataHs_reg;  //* 延时一拍
    end

    // 帧丢弃计数器
    reg [3:0] frame_cnt = 0;
    reg       frame_ready = 0;

    always @(posedge PCLK or posedge Rst_p) begin
        if (Rst_p) begin
            frame_cnt   <= 0;
            frame_ready <= 0;
        end else if (~r_Vsync & Vsync) begin  // Vsync 上升沿
            if (frame_cnt < 4'd10)
                frame_cnt <= frame_cnt + 1;
            if (frame_cnt == 4'd9)
                frame_ready <= 1'b1; // 第10帧开始采集
        end
    end

    // 数据拼接
    reg       byte_flag = 0;
    reg [7:0] high_byte = 0;
    reg       href_last = 0;
    reg       last_pixel_hold = 0; // 行尾保持最后一个像素的标志

    always @(posedge PCLK or posedge Rst_p) begin
        if (Rst_p) begin
            DataPixel   <= 16'd0;
            DataValid   <= 1'b0;
            Xaddr       <= 12'd0;
            Yaddr       <= 12'd0;
            DataHs_reg  <= 1'b0;
            DataVs      <= 1'b0;
            byte_flag   <= 1'b0;
            href_last   <= 1'b0;
            last_pixel_hold <= 1'b0;
        end else begin
            href_last <= r_Href;
            DataHs_reg<= r_Href;
            DataVs    <= r_Vsync;

            if (frame_ready) begin
                if (r_Href) begin
                    if (!href_last) begin
                        byte_flag <= 0;
                        Xaddr     <= 0;
                        DataValid <= 0;
                        last_pixel_hold <= 0;
                    end
                    if (!byte_flag) begin
                        high_byte <= r_Data;
                        byte_flag <= 1;
                    end else begin
                        DataPixel <= {high_byte, r_Data};
                        DataValid <= 1;
                        byte_flag <= 0;
                        Xaddr     <= Xaddr + 1;
                        // 如果下一拍 href 会无效，说明是最后一个pixel
                        if (href_last && !Href)
                            last_pixel_hold <= 1;
                    end
                end else begin
                    if (last_pixel_hold) begin
                        // 延迟一个周期拉低 DataValid
                        DataValid <= 1;
                        last_pixel_hold <= 0;
                    end else begin
                        DataValid <= 0;
                    end
                    byte_flag <= 0;
                    if (href_last && !r_Href) begin
                        Yaddr <= Yaddr + 1;
                    end
                end
            end else begin
                DataValid <= 0; // 丢弃前10帧
            end
        end
    end
endmodule