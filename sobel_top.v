//=============================================================================
// 文件    : sobel_top.v
// 项目    : 基于 Artix-7 的实时 Sobel 边缘检测加速系统
// 器件    : Xilinx Artix-7 XC7A35T-2FGG484 (ACX720)
// 功能    : 顶层。OV5640 → 灰度 → 行缓存开窗 → Sobel 双卷积 → 阈值判决 → HDMI
// 说明    : 1) 采集域与像素域经 16bit 异步 FIFO 隔离（PCLK 与像素时钟异步）；
//           2) 处理通路全流水，每拍 1 像素，不缓存整帧；
//           3) 显示时序由 hdmi_timing 产生，按摄像头场同步对齐帧起始。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module sobel_top #(
    parameter integer H_ACTIVE   = 1280,      // 有效行像素
    parameter integer H_FP       = 110,       // 行前肩
    parameter integer H_SYNC     = 40,        // 行同步
    parameter integer H_BP       = 220,       // 行后肩
    parameter integer V_ACTIVE   = 720,       // 有效行数
    parameter integer V_FP       = 5,
    parameter integer V_SYNC     = 5,
    parameter integer V_BP       = 20,
    parameter integer V_TOTAL    = 1500,      // 720p30：场消隐加倍，帧率 = 74.17M/(1650*1500)
    parameter integer TH_INIT    = 64,        // 初始阈值
    parameter integer TH_STEP    = 8,         // 阈值步进
    parameter         SIM_MODE   = 0          // 1：用行为级串行器替代 ODDR/OBUFDS
)(
    // 板级时钟与复位
    input  wire        clk_50m,
    input  wire        rst_n,                 // 低有效，按键复位
    input  wire [1:0]  key,                   // KEY1: 阈值 +   KEY2: 阈值 -

    // OV5640 DVP 接口
    input  wire        cam_pclk,
    input  wire        cam_href,
    input  wire        cam_vsync,
    input  wire [7:0]  cam_data,
    inout  wire        sccb_scl,
    inout  wire        sccb_sda,
    output wire        cam_xclk,
    output wire        cam_rst_n,

    // HDMI TMDS 输出
    output wire [2:0]  tmds_d_p,
    output wire [2:0]  tmds_d_n,
    output wire        tmds_clk_p,
    output wire        tmds_clk_n,

    // 调试串口
    output wire        uart_tx,
    // 状态指示（可选，不接 LED 时删掉即可）
    output wire        led_locked,
    output wire        led_frame
);

    //---------------------------------------------------------------- clock
    wire clk_pix;
    wire clk_5x;
    wire clk_xclk;
    wire locked;
    wire rst_n_pix;

    clk_rst_gen #(
        .SIM_MODE (SIM_MODE)
    ) u_clk_rst_gen (
        .clk_50m   (clk_50m),
        .rst_n_in  (rst_n),
        .clk_pix   (clk_pix),
        .clk_5x    (clk_5x),
        .clk_xclk  (clk_xclk),
        .locked    (locked),
        .rst_n_pix (rst_n_pix)
    );

    assign cam_xclk   = clk_xclk;
    assign cam_rst_n  = rst_n_pix;
    assign led_locked = locked;
    // 注：OV5640 模组的 PWDN 在模块内部下拉，RTL 不再引出

    //--------------------------------------------------------- SCCB 配置
    wire cfg_done;

    sccb_cfg u_sccb_cfg (
        .clk      (clk_pix),
        .rst_n    (rst_n_pix),
        .scl      (sccb_scl),
        .sda      (sccb_sda),
        .cfg_done (cfg_done)
    );

    //------------------------------------------------------------ 采集
    wire [15:0] pix_data;
    wire        pix_valid;
    wire        frame_start;
    wire        line_start;
    wire        fifo_full;

    dvp_capture u_dvp_capture (
        .cam_pclk    (cam_pclk),
        .cam_href    (cam_href),
        .cam_vsync   (cam_vsync),
        .cam_data    (cam_data),
        .clk_pix     (clk_pix),
        .rst_n_pix   (rst_n_pix),
        .pix_data    (pix_data),
        .pix_valid   (pix_valid),
        .frame_start (frame_start),
        .line_start  (line_start),
        .fifo_full   (fifo_full)
    );

    //------------------------------------------------- 阈值（按键）控制
    wire [7:0] threshold;

    dbg_ctrl #(
        .CLK_HZ  (74166667),
        .TH_INIT (TH_INIT),
        .TH_STEP (TH_STEP)
    ) u_dbg_ctrl (
        .clk         (clk_pix),
        .rst_n       (rst_n_pix),
        .key         (key),
        .frame_start (frame_start),
        .threshold   (threshold),
        .uart_tx     (uart_tx),
        .led_frame   (led_frame)
    );

    //-------------------------------------------------- 像素流水线
    wire edge_bit;
    wire edge_valid;

    pixel_pipe #(
        .H_ACTIVE (H_ACTIVE)
    ) u_pixel_pipe (
        .clk        (clk_pix),
        .rst_n      (rst_n_pix),
        .pix_data   (pix_data),
        .pix_valid  (pix_valid),
        .frame_start(frame_start),
        .threshold  (threshold),
        .edge_bit   (edge_bit),
        .edge_valid (edge_valid)
    );

    //----------------------------------------------------- 显示输出
    video_out #(
        .H_ACTIVE (H_ACTIVE),
        .H_FP     (H_FP),
        .H_SYNC   (H_SYNC),
        .H_BP     (H_BP),
        .V_ACTIVE (V_ACTIVE),
        .V_FP     (V_FP),
        .V_SYNC   (V_SYNC),
        .V_BP     (V_BP),
        .V_TOTAL  (V_TOTAL),
        .SIM_MODE (SIM_MODE)
    ) u_video_out (
        .clk_pix     (clk_pix),
        .clk_5x      (clk_5x),
        .rst_n       (rst_n_pix),
        .edge_bit    (edge_bit),
        .edge_valid  (edge_valid),
        .frame_start (frame_start),
        .tmds_d_p    (tmds_d_p),
        .tmds_d_n    (tmds_d_n),
        .tmds_clk_p  (tmds_clk_p),
        .tmds_clk_n  (tmds_clk_n)
    );

endmodule

`default_nettype wire
