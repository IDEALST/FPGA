//=============================================================================
// 文件    : video_out.v
// 功能    : 显示输出
//           1) hdmi_timing 产生 1280×720 时序；
//           2) sync_fifo 把流水线输出的 1bit 边缘按顺序缓存，按显示 de 取出，
//              吸收采集与显示之间的微小速率差；
//           3) 三通道 TMDS 编码 + 串行化，输出 HDMI。
// 说明    : 帧起始用摄像头 VSYNC 对齐（flush），保证画面从帧首开始；
//           若采集速率低于显示速率，画面下部会出现黑边（无整帧缓存的正常现象）。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module video_out #(
    parameter integer H_ACTIVE = 1280,
    parameter integer H_FP     = 110,
    parameter integer H_SYNC   = 40,
    parameter integer H_BP     = 220,
    parameter integer V_ACTIVE = 720,
    parameter integer V_FP     = 5,
    parameter integer V_SYNC   = 5,
    parameter integer V_BP     = 20,
    parameter integer V_TOTAL  = 1500,
    parameter integer SIM_MODE = 0
)(
    input  wire        clk_pix,
    input  wire        clk_5x,
    input  wire        rst_n,
    input  wire        edge_bit,
    input  wire        edge_valid,
    input  wire        frame_start,
    output wire [2:0]  tmds_d_p,
    output wire [2:0]  tmds_d_n,
    output wire        tmds_clk_p,
    output wire        tmds_clk_n
);

    //------------------------------------------------------- 视频时序
    wire        hsync, vsync, de;
    wire [11:0] x, y;

    hdmi_timing #(
        .H_ACTIVE (H_ACTIVE),
        .H_FP     (H_FP),
        .H_SYNC   (H_SYNC),
        .H_BP     (H_BP),
        .V_ACTIVE (V_ACTIVE),
        .V_FP     (V_FP),
        .V_SYNC   (V_SYNC),
        .V_BP     (V_BP),
        .V_TOTAL  (V_TOTAL)
    ) u_hdmi_timing (
        .clk        (clk_pix),
        .rst_n      (rst_n),
        .frame_lock (frame_start),
        .hsync      (hsync),
        .vsync      (vsync),
        .de         (de),
        .x          (x),
        .y          (y)
    );

    //--------------------------------------------------- 像素对齐 FIFO
    wire px_bit;
    wire fifo_empty;

    sync_fifo #(
        .DW (1),
        .AW (12)
    ) u_align_fifo (
        .clk   (clk_pix),
        .rst_n (rst_n),
        .flush (frame_start),
        .winc  (edge_valid),
        .wdata (edge_bit),
        .wfull (),
        .rinc  (de),
        .rdata (px_bit),
        .rempty(fifo_empty)
    );

    wire px_valid = de & ~fifo_empty;

    //------------------------------------------- 黑白画面（边缘=白）
    wire [7:0] pix_gray = (px_valid & px_bit) ? 8'hFF : 8'h00;
    wire [23:0] rgb     = {pix_gray, pix_gray, pix_gray};

    //------------------------------------------------------- TMDS 编码
    wire [9:0] tmds_b, tmds_g, tmds_r, tmds_c;

    tmds_encoder u_enc_b (
        .clk  (clk_pix),
        .rst_n(rst_n),
        .din  (rgb[7:0]),
        .c0   (hsync),
        .c1   (vsync),
        .de   (de),
        .dout (tmds_b)
    );

    tmds_encoder u_enc_g (
        .clk  (clk_pix),
        .rst_n(rst_n),
        .din  (rgb[15:8]),
        .c0   (1'b0),
        .c1   (1'b0),
        .de   (de),
        .dout (tmds_g)
    );

    tmds_encoder u_enc_r (
        .clk  (clk_pix),
        .rst_n(rst_n),
        .din  (rgb[23:16]),
        .c0   (1'b0),
        .c1   (1'b0),
        .de   (de),
        .dout (tmds_r)
    );

    // 时钟通道：固定 1111100000 图案
    assign tmds_c = 10'b1111100000;

    //------------------------------------------------------- 串行输出
    tmds_serdes #(.SIM_MODE(SIM_MODE)) u_ser_b (
        .clk_pix (clk_pix),
        .clk_5x  (clk_5x),
        .rst_n   (rst_n),
        .din     (tmds_b),
        .tmds_p  (tmds_d_p[0]),
        .tmds_n  (tmds_d_n[0])
    );

    tmds_serdes #(.SIM_MODE(SIM_MODE)) u_ser_g (
        .clk_pix (clk_pix),
        .clk_5x  (clk_5x),
        .rst_n   (rst_n),
        .din     (tmds_g),
        .tmds_p  (tmds_d_p[1]),
        .tmds_n  (tmds_d_n[1])
    );

    tmds_serdes #(.SIM_MODE(SIM_MODE)) u_ser_r (
        .clk_pix (clk_pix),
        .clk_5x  (clk_5x),
        .rst_n   (rst_n),
        .din     (tmds_r),
        .tmds_p  (tmds_d_p[2]),
        .tmds_n  (tmds_d_n[2])
    );

    tmds_serdes #(.SIM_MODE(SIM_MODE)) u_ser_c (
        .clk_pix (clk_pix),
        .clk_5x  (clk_5x),
        .rst_n   (rst_n),
        .din     (tmds_c),
        .tmds_p  (tmds_clk_p),
        .tmds_n  (tmds_clk_n)
    );

endmodule

`default_nettype wire
