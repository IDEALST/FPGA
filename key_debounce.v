//=============================================================================
// 文件    : key_debounce.v
// 功能    : 按键消抖（默认 20ms），按下时输出单周期脉冲
// 说明    : 板载按键低有效（按下为 0）；输入先两级同步，再计数确认
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module key_debounce #(
    parameter integer CLK_HZ = 74166667,
    parameter integer MS     = 20,
    parameter integer NKEY   = 2
)(
    input  wire            clk,
    input  wire            rst_n,
    input  wire [NKEY-1:0] key,
    output reg  [NKEY-1:0] press        // 按下瞬间产生 1 拍脉冲
);

    localparam integer CNT_MAX   = (CLK_HZ / 1000) * MS;
    localparam [31:0]  CNT_MAX32 = CNT_MAX;

    (* ASYNC_REG = "TRUE" *) reg [NKEY-1:0] q1, q2;
    reg [NKEY-1:0] stable;              // 消抖后的电平
    reg [31:0]     cnt [0:NKEY-1];
    reg [NKEY-1:0] press_r;
    integer i;

    wire [NKEY-1:0] diff = q2 ^ stable; // 与稳定值不同则需要计时

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q1      <= {NKEY{1'b1}};
            q2      <= {NKEY{1'b1}};
            stable  <= {NKEY{1'b1}};
            press_r <= {NKEY{1'b0}};
            press   <= {NKEY{1'b0}};
            for (i = 0; i < NKEY; i = i + 1)
                cnt[i] <= 32'd0;
        end else begin
            q1 <= key;
            q2 <= q1;
            press   <= press_r;
            press_r <= {NKEY{1'b0}};

            for (i = 0; i < NKEY; i = i + 1) begin
                if (diff[i]) begin
                    if (cnt[i] >= CNT_MAX32 - 32'd1) begin
                        cnt[i]     <= 32'd0;
                        stable[i]  <= q2[i];
                        // 1 → 0 视为按下
                        if (!q2[i])
                            press_r[i] <= 1'b1;
                    end else begin
                        cnt[i] <= cnt[i] + 32'd1;
                    end
                end else begin
                    cnt[i] <= 32'd0;
                end
            end
        end
    end

endmodule

`default_nettype wire
