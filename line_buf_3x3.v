//=============================================================================
// 文件    : line_buf_3x3.v
// 功能    : 双行缓存 + 3×3 窗口生成
//           两片 HACT×8 双口 RAM 分别保存第 n-2 行与第 n-1 行，当前行直通；
//           读地址与写地址相同（READ_FIRST 模式），读出的是上一行同列像素。
//           9 个移位寄存器每拍整体右移 1 位，滑出完整窗口。
// 输出    : win = {p1,p2,p3, p4,p5,p6, p7,p8,p9}
//           p1 为左上（第 n-2 行、左列），p9 为右下（当前行、当前列）
// 延迟    : 2 拍（BRAM 读 1 拍 + 窗口移位 1 拍）
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module line_buf_3x3 #(
    parameter integer HACT = 1280
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_start,
    input  wire        de_in,
    input  wire [7:0]  din,
    output reg         de_out,
    output reg  [71:0] win
);

    localparam [10:0] HACT11 = HACT;

    //------------------------------------------------------ 行缓存
    (* ram_style = "block" *) reg [7:0] ram_a [0:HACT-1];   // 第 n-2 行
    (* ram_style = "block" *) reg [7:0] ram_b [0:HACT-1];   // 第 n-1 行

    reg [10:0] wr_ptr;
    reg [7:0]  qa, qb;
    reg [7:0]  din_d;
    reg        de_d1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 11'd0;
            qa     <= 8'd0;
            qb     <= 8'd0;
            din_d  <= 8'd0;
            de_d1  <= 1'b0;
        end else begin
            if (frame_start)
                wr_ptr <= 11'd0;

            if (de_in) begin
                ram_b[wr_ptr] <= din;          // 当前行写入 B
                ram_a[wr_ptr] <= ram_b[wr_ptr];// B 的旧值（第 n-1 行）进入 A
                wr_ptr <= (wr_ptr == HACT11 - 11'd1) ? 11'd0 : (wr_ptr + 11'd1);
            end

            // 同地址读，得到写入前的旧值
            qa     <= ram_a[wr_ptr];
            qb     <= ram_b[wr_ptr];
            din_d  <= din;
            de_d1  <= de_in;
        end
    end

    //------------------------------------------------- 3×3 窗口寄存器
    reg [7:0] p1, p2, p3;
    reg [7:0] p4, p5, p6;
    reg [7:0] p7, p8, p9;
    reg       de_d2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p1 <= 8'd0; p2 <= 8'd0; p3 <= 8'd0;
            p4 <= 8'd0; p5 <= 8'd0; p6 <= 8'd0;
            p7 <= 8'd0; p8 <= 8'd0; p9 <= 8'd0;
            de_d2 <= 1'b0;
        end else if (de_d1) begin
            p1 <= p2;  p2 <= p3;  p3 <= qa;   // 第 n-2 行
            p4 <= p5;  p5 <= p6;  p6 <= qb;   // 第 n-1 行
            p7 <= p8;  p8 <= p9;  p9 <= din_d;// 当前行
            de_d2 <= 1'b1;
        end else begin
            de_d2 <= 1'b0;
        end
    end

    //------------------------------------------ 帧首 2 行屏蔽
    reg [10:0] ycnt;
    reg [10:0] xcnt;
    reg [10:0] ycnt_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ycnt   <= 11'd0;
            xcnt   <= 11'd0;
            ycnt_d <= 11'd0;
        end else begin
            if (frame_start) begin
                ycnt <= 11'd0;
                xcnt <= 11'd0;
            end else if (de_in) begin
                if (xcnt == HACT11 - 11'd1) begin
                    xcnt <= 11'd0;
                    ycnt <= ycnt + 11'd1;
                end else begin
                    xcnt <= xcnt + 11'd1;
                end
            end
            ycnt_d <= ycnt;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            de_out <= 1'b0;
            win    <= 72'd0;
        end else begin
            de_out <= de_d2 & (ycnt_d >= 11'd2);
            win    <= {p1, p2, p3, p4, p5, p6, p7, p8, p9};
        end
    end

endmodule

`default_nettype wire
