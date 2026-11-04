//=============================================================================
// 文件    : thresh_bin.v
// 功能    : 梯度幅值合并 + 阈值判决（1 级流水）
// 公式    : G ≈ |Gx| + |Gy|（省去开方，最大相对误差约 8%）
//           把 0~2040 的幅度右移 3 位压缩到 0~255，再与阈值比较
// 输出    : edge = 1 时输出白色（255），否则黑色（0）
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module thresh_bin (
    input  wire               clk,
    input  wire               rst_n,
    input  wire signed [10:0] gx,
    input  wire signed [10:0] gy,
    input  wire               de_in,
    input  wire [7:0]         threshold,
    output reg                edge,
    output reg                de_out
);

    // 绝对值
    wire [10:0] ax = gx[10] ? ((~gx) + 11'd1) : gx;
    wire [10:0] ay = gy[10] ? ((~gy) + 11'd1) : gy;

    // 合并并压缩到 8bit
    wire [11:0] gmag = {1'b0, ax} + {1'b0, ay};   // ≤ 2040
    wire [7:0]  g8   = gmag[10:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge   <= 1'b0;
            de_out <= 1'b0;
        end else begin
            edge   <= (g8 >= threshold);
            de_out <= de_in;
        end
    end

endmodule

`default_nettype wire
