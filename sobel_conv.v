//=============================================================================
// 文件    : sobel_conv.v
// 功能    : Sobel 双方向卷积，Gx / Gy 并行计算，2 级流水
// 公式    : Gx = (p3 + 2*p6 + p9) - (p1 + 2*p4 + p7)     水平梯度
//           Gy = (p7 + 2*p8 + p9) - (p1 + 2*p2 + p3)     垂直梯度
// 实现    : 2 倍用左移 1 位；负项在第二级统一相减；无反相器级联带来的额外延迟
// 范围    : |Gx|,|Gy| ≤ 4*255 = 1020，用 11bit 有符号数表示
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module sobel_conv (
    input  wire              clk,
    input  wire              rst_n,
    input  wire [71:0]       win,
    input  wire              de_in,
    output reg  signed [10:0] gx,
    output reg  signed [10:0] gy,
    output reg               de_out
);

    // 窗口拆解：p1..p9
    wire [7:0] p1 = win[71:64];
    wire [7:0] p2 = win[63:56];
    wire [7:0] p3 = win[55:48];
    wire [7:0] p4 = win[47:40];
    wire [7:0] p5 = win[39:32];
    wire [7:0] p6 = win[31:24];
    wire [7:0] p7 = win[23:16];
    wire [7:0] p8 = win[15:8];
    wire [7:0] p9 = win[7:0];

    //----------------------------------------- 第 1 级：正/负三项之和
    reg [10:0] px, nx, py, ny;
    reg        v1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            px <= 11'd0; nx <= 11'd0;
            py <= 11'd0; ny <= 11'd0;
            v1 <= 1'b0;
        end else begin
            px <= {3'd0, p3} + {2'd0, p6, 1'b0} + {3'd0, p9};   // 右列
            nx <= {3'd0, p1} + {2'd0, p4, 1'b0} + {3'd0, p7};   // 左列
            py <= {3'd0, p7} + {2'd0, p8, 1'b0} + {3'd0, p9};   // 下行
            ny <= {3'd0, p1} + {2'd0, p2, 1'b0} + {3'd0, p3};   // 上行
            v1 <= de_in;
        end
    end

    //------------------------------------------------- 第 2 级：相减
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gx     <= 11'sd0;
            gy     <= 11'sd0;
            de_out <= 1'b0;
        end else begin
            gx     <= $signed({1'b0, px}) - $signed({1'b0, nx});
            gy     <= $signed({1'b0, py}) - $signed({1'b0, ny});
            de_out <= v1;
        end
    end

endmodule

`default_nettype wire
