//=============================================================================
// 文件    : tmds_serdes.v
// 功能    : TMDS 10bit 并串转换
//           每个像素周期（clk_pix）串出 10bit，用 5 倍时钟（clk_5x）DDR 输出，
//           即每个 clk_5x 周期送出 2bit。
// 实现    : 移位寄存器 + ODDR + OBUFDS；SIM_MODE=1 时用纯行为级模型，便于仿真。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module tmds_serdes #(
    parameter integer SIM_MODE = 0
)(
    input  wire       clk_pix,
    input  wire       clk_5x,
    input  wire       rst_n,
    input  wire [9:0] din,
    output wire       tmds_p,
    output wire       tmds_n
);

    reg [9:0] shift;
    reg [2:0] ph;          // 0..4，对应一个像素周期内的 5 个串行节拍
    reg       d1, d2;

    always @(posedge clk_5x or negedge rst_n) begin
        if (!rst_n) begin
            shift <= 10'd0;
            ph    <= 3'd0;
            d1    <= 1'b0;
            d2    <= 1'b0;
        end else begin
            if (ph == 3'd4) begin
                // 新像素：装载，并先送出 bit0 / bit1
                shift <= din;
                d1    <= din[0];
                d2    <= din[1];
                ph    <= 3'd0;
            end else begin
                shift <= {2'b00, shift[9:2]};
                d1    <= shift[2];
                d2    <= shift[3];
                ph    <= ph + 3'd1;
            end
        end
    end

    generate
    if (SIM_MODE != 0) begin : g_sim
        // 行为级：单端输出，便于 iverilog / xsim 波形观察
        reg q;
        always @(posedge clk_5x) q <= d1;
        assign tmds_p = q;
        assign tmds_n = ~q;
    end else begin : g_real
        wire q;
        ODDR #(
            .DDR_CLK_EDGE ("SAME_EDGE"),
            .INIT         (1'b0),
            .SRTYPE       ("SYNC")
        ) u_oddr (
            .Q  (q),
            .C  (clk_5x),
            .CE (1'b1),
            .D1 (d1),
            .D2 (d2),
            .R  (1'b0),
            .S  (1'b0)
        );

        OBUFDS u_obufds (
            .O  (tmds_p),
            .OB (tmds_n),
            .I  (q)
        );
    end
    endgenerate

endmodule

`default_nettype wire
