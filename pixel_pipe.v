//=============================================================================
// 文件    : pixel_pipe.v
// 功能    : 像素流水线（四级）
//           rgb565_split → gray_conv → line_buf_3x3 → sobel_conv → thresh_bin
// 时序    : 每拍处理 1 个像素；总延迟 = 2 行 + 9 个像素周期
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module pixel_pipe #(
    parameter integer H_ACTIVE = 1280
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] pix_data,
    input  wire        pix_valid,
    input  wire        frame_start,
    input  wire [7:0]  threshold,
    output wire        edge_bit,
    output wire        edge_valid
);

    //-------------------------------------------------- RGB565 拆分
    wire [7:0] r, g, b;
    wire       rgb_valid;

    rgb565_split u_rgb565_split (
        .clk       (clk),
        .rst_n     (rst_n),
        .pix_data  (pix_data),
        .pix_valid (pix_valid),
        .r         (r),
        .g         (g),
        .b         (b),
        .rgb_valid (rgb_valid)
    );

    //------------------------------------------------------ 灰度
    wire [7:0] gray;
    wire       gray_valid;

    gray_conv u_gray_conv (
        .clk        (clk),
        .rst_n      (rst_n),
        .r          (r),
        .g          (g),
        .b          (b),
        .din_valid  (rgb_valid),
        .gray       (gray),
        .dout_valid (gray_valid)
    );

    //------------------------------------------------ 行缓存 + 开窗
    wire [71:0] win;
    wire        win_valid;

    line_buf_3x3 #(
        .HACT (H_ACTIVE)
    ) u_line_buf_3x3 (
        .clk         (clk),
        .rst_n       (rst_n),
        .frame_start (frame_start),
        .de_in       (gray_valid),
        .din         (gray),
        .de_out      (win_valid),
        .win         (win)
    );

    //----------------------------------------------------- 卷积
    wire signed [10:0] gx, gy;
    wire               conv_valid;

    sobel_conv u_sobel_conv (
        .clk      (clk),
        .rst_n    (rst_n),
        .win      (win),
        .de_in    (win_valid),
        .gx       (gx),
        .gy       (gy),
        .de_out   (conv_valid)
    );

    //------------------------------------------------- 阈值判决
    thresh_bin u_thresh_bin (
        .clk       (clk),
        .rst_n     (rst_n),
        .gx        (gx),
        .gy        (gy),
        .de_in     (conv_valid),
        .threshold (threshold),
        .edge      (edge_bit),
        .de_out    (edge_valid)
    );

endmodule

`default_nettype wire
