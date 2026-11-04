//=============================================================================
// 文件    : async_fifo.v
// 功能    : 格雷码指针的异步 FIFO（Clifford Cummings 经典结构）
// 用途    : OV5640 的 PCLK 域 → FPGA 像素时钟域，传递 16bit RGB565 像素
// 说明    : 双时钟、双端口 RAM 推断为 BRAM；读写指针各打两拍同步；
//           full / empty 均为寄存器输出，无组合毛刺。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module async_fifo #(
    parameter integer DW = 16,      // 数据位宽
    parameter integer AW = 8        // 地址位宽（深度 = 2^AW）
)(
    // 写侧
    input  wire          wclk,
    input  wire          wrst_n,
    input  wire          winc,
    input  wire [DW-1:0] wdata,
    output reg           wfull,
    // 读侧
    input  wire          rclk,
    input  wire          rrst_n,
    input  wire          rinc,
    output wire [DW-1:0] rdata,
    output reg           rempty
);

    localparam integer N = AW + 1;

    reg [DW-1:0] mem [0:(1<<AW)-1];

    reg  [N-1:0] wbin, wgray;
    reg  [N-1:0] rbin, rgray;

    // 跨时钟域同步
    (* ASYNC_REG = "TRUE" *) reg [N-1:0] rgray_wq1, rgray_wq2;
    (* ASYNC_REG = "TRUE" *) reg [N-1:0] wgray_rq1, wgray_rq2;

    //--------------------------------------------------- 写侧
    wire        winc_real = winc & ~wfull;
    wire [N-1:0] wbin_nxt  = wbin + {{(N-1){1'b0}}, winc_real};
    wire [N-1:0] wgray_nxt = (wbin_nxt >> 1) ^ wbin_nxt;
    wire [N-1:0] wgray_sync_r = rgray_wq2;
    wire [N-1:0] wfull_val = (wgray_nxt == {~wgray_sync_r[N-1:N-2],
                                            wgray_sync_r[N-3:0]});

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            wbin  <= {N{1'b0}};
            wgray <= {N{1'b0}};
            wfull <= 1'b0;
        end else begin
            wbin  <= wbin_nxt;
            wgray <= wgray_nxt;
            wfull <= wfull_val;
        end
    end

    always @(posedge wclk) begin
        if (winc_real)
            mem[wbin[AW-1:0]] <= wdata;
    end

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin
            rgray_wq1 <= {N{1'b0}};
            rgray_wq2 <= {N{1'b0}};
        end else begin
            rgray_wq1 <= rgray;
            rgray_wq2 <= rgray_wq1;
        end
    end

    //--------------------------------------------------- 读侧
    wire        rinc_real = rinc & ~rempty;
    wire [N-1:0] rbin_nxt  = rbin + {{(N-1){1'b0}}, rinc_real};
    wire [N-1:0] rgray_nxt = (rbin_nxt >> 1) ^ rbin_nxt;
    wire [N-1:0] rgray_sync_w = wgray_rq2;
    wire         rempty_val = (rgray_nxt == rgray_sync_w);

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            rbin   <= {N{1'b0}};
            rgray  <= {N{1'b0}};
            rempty <= 1'b1;
        end else begin
            rbin   <= rbin_nxt;
            rgray  <= rgray_nxt;
            rempty <= rempty_val;
        end
    end

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin
            wgray_rq1 <= {N{1'b0}};
            wgray_rq2 <= {N{1'b0}};
        end else begin
            wgray_rq1 <= wgray;
            wgray_rq2 <= wgray_rq1;
        end
    end

    // 读数据：寄存器输出，配合 BRAM 的 1 拍延迟
    reg [DW-1:0] rdata_r;
    always @(posedge rclk) begin
        rdata_r <= mem[rbin[AW-1:0]];
    end
    assign rdata = rdata_r;

endmodule

`default_nettype wire
