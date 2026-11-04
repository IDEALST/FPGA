//=============================================================================
// 文件    : vid_sync.v
// 功能    : 跨时钟域同步 + 边沿检测（通用）
// 说明    : 两级触发器同步异步控制信号（VSYNC/HREF/PCLK 等），
//           并对同步后的信号做上升沿 / 下降沿检测，输出单周期脉冲。
//           备注：只用于 1bit 控制类信号；数据要跨域请用 async_fifo。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module vid_sync #(
    parameter integer WIDTH = 1
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire [WIDTH-1:0] async_in,
    output wire [WIDTH-1:0] sync_out,
    output wire [WIDTH-1:0] rise,
    output wire [WIDTH-1:0] fall
);

    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] q1;
    (* ASYNC_REG = "TRUE" *) reg [WIDTH-1:0] q2;
    reg [WIDTH-1:0] q3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1 <= {WIDTH{1'b0}};
            q2 <= {WIDTH{1'b0}};
            q3 <= {WIDTH{1'b0}};
        end else begin
            q1 <= async_in;
            q2 <= q1;
            q3 <= q2;
        end
    end

    assign sync_out = q2;
    assign rise     = q2 & ~q3;
    assign fall     = ~q2 & q3;

endmodule

`default_nettype wire
