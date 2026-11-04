//=============================================================================
// 文件    : dvp_capture.v
// 功能    : OV5640 DVP 接口采集
//           - cam_pclk 域：HREF 有效期间按“高字节在前”拼成 16bit RGB565 像素
//           - 经 16bit 异步 FIFO 跨到像素时钟域
//           - VSYNC / HREF 经两级同步后产生 frame_start / line_start 单周期脉冲
// 说明    : OV5640 在 HREF 有效期内连续输出字节：先 {R[7:3],G[7:5]}，后 {G[4:0],B[7:3]}。
//           用 HREF 上升沿复位半字节标志，避免上电相位不定造成的红蓝互换。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module dvp_capture (
    // 采集侧
    input  wire        cam_pclk,
    input  wire        cam_href,
    input  wire        cam_vsync,
    input  wire [7:0]  cam_data,
    // 像素侧
    input  wire        clk_pix,
    input  wire        rst_n_pix,
    output wire [15:0] pix_data,
    output wire        pix_valid,
    output reg         frame_start,
    output reg         line_start,
    output wire        fifo_full
);

    //-------------------------------------------------- cam_pclk 域
    reg  [7:0]  byte_hi;
    reg         half;           // 0: 下一个是高字节  1: 下一个是低字节
    reg  [15:0] pix_w;
    reg         pix_we;
    reg         vs_d, href_d;
    reg         fs_tgl;         // 每一帧翻转一次，跨域用
    reg         ls_tgl;         // 每一行翻转一次，跨域用

    always @(posedge cam_pclk) begin
        vs_d   <= cam_vsync;
        href_d <= cam_href;

        // 帧起始 / 行起始：用翻转标志跨域
        if (cam_vsync & ~vs_d)  fs_tgl <= ~fs_tgl;
        if (cam_href  & ~href_d) ls_tgl <= ~ls_tgl;

        if (cam_href) begin
            if (!half) begin
                byte_hi <= cam_data;
                half    <= 1'b1;
                pix_we  <= 1'b0;
            end else begin
                pix_w   <= {byte_hi, cam_data};   // 高字节在前
                half    <= 1'b0;
                pix_we  <= 1'b1;
            end
        end else begin
            half   <= 1'b0;                       // 行结束复位相位
            pix_we <= 1'b0;
        end
    end

    //-------------------------------------------------- 异步 FIFO
    wire [15:0] fifo_dout;
    wire        fifo_empty;
    wire        fifo_rd;

    async_fifo #(
        .DW (16),
        .AW (8)                 // 深度 256 像素
    ) u_pix_fifo (
        .wclk   (cam_pclk),
        .wrst_n (rst_n_pix),    // 注：复位取自像素域，上电后一起释放即可
        .winc   (pix_we),
        .wdata  (pix_w),
        .wfull  (fifo_full),
        .rclk   (clk_pix),
        .rrst_n (rst_n_pix),
        .rinc   (fifo_rd),
        .rdata  (fifo_dout),
        .rempty (fifo_empty)
    );

    assign fifo_rd = ~fifo_empty;

    // FIFO 读数据有 1 拍延迟，valid 同步延迟一拍
    reg rvalid;
    always @(posedge clk_pix or negedge rst_n_pix) begin
        if (!rst_n_pix) rvalid <= 1'b0;
        else            rvalid <= fifo_rd;
    end

    assign pix_data  = fifo_dout;
    assign pix_valid = rvalid;

    //------------------------------------------ VSYNC / HREF 跨域
    (* ASYNC_REG = "TRUE" *) reg fs_q1, fs_q2, fs_q3;
    (* ASYNC_REG = "TRUE" *) reg ls_q1, ls_q2, ls_q3;

    always @(posedge clk_pix or negedge rst_n_pix) begin
        if (!rst_n_pix) begin
            fs_q1 <= 1'b0; fs_q2 <= 1'b0; fs_q3 <= 1'b0;
            ls_q1 <= 1'b0; ls_q2 <= 1'b0; ls_q3 <= 1'b0;
            frame_start <= 1'b0;
            line_start  <= 1'b0;
        end else begin
            fs_q1 <= fs_tgl;  fs_q2 <= fs_q1;  fs_q3 <= fs_q2;
            ls_q1 <= ls_tgl;  ls_q2 <= ls_q1;  ls_q3 <= ls_q2;
            frame_start <= fs_q2 ^ fs_q3;
            line_start  <= ls_q2 ^ ls_q3;
        end
    end

endmodule

`default_nettype wire
