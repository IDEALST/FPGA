//=============================================================================
// 文件    : hdmi_timing.v
// 功能    : 1280×720 视频时序发生器（CEA-861）
//           720p30：像素时钟 74.1667MHz，H 总长 1650，V 总长 1500（场消隐加倍）
// 输出    : hsync / vsync 正极性，de 为数据有效
// 说明    : frame_lock 由摄像机场同步给出，用于把显示帧与采集帧对齐
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module hdmi_timing #(
    parameter integer H_ACTIVE = 1280,
    parameter integer H_FP     = 110,
    parameter integer H_SYNC   = 40,
    parameter integer H_BP     = 220,
    parameter integer V_ACTIVE = 720,
    parameter integer V_FP     = 5,
    parameter integer V_SYNC   = 5,
    parameter integer V_BP     = 20,
    parameter integer V_TOTAL  = 1500
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_lock,
    output reg         hsync,
    output reg         vsync,
    output reg         de,
    output reg  [11:0] x,
    output reg  [11:0] y
);

    localparam integer H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;
    localparam [11:0]  H_TOTAL12 = H_TOTAL;
    localparam [11:0]  V_TOTAL12 = V_TOTAL;

    wire [11:0] x_nxt = (x == H_TOTAL12 - 12'd1) ? 12'd0 : (x + 12'd1);
    wire        y_en  = (x == H_TOTAL12 - 12'd1);
    wire [11:0] y_nxt = (y == V_TOTAL12 - 12'd1) ? 12'd0 : (y + 12'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 12'd0;
            y <= 12'd0;
        end else if (frame_lock) begin
            x <= 12'd0;
            y <= 12'd0;
        end else if (y_en) begin
            x <= 12'd0;
            y <= y_nxt;
        end else begin
            x <= x_nxt;
        end
    end

    //----------------------------------------------------- 同步信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hsync <= 1'b0;
            vsync <= 1'b0;
            de    <= 1'b0;
        end else begin
            hsync <= (x >= (H_ACTIVE + H_FP)) && (x < (H_ACTIVE + H_FP + H_SYNC));
            vsync <= (y >= (V_ACTIVE + V_FP)) && (y < (V_ACTIVE + V_FP + V_SYNC));
            de    <= (x < H_ACTIVE) && (y < V_ACTIVE);
        end
    end

endmodule

`default_nettype wire
