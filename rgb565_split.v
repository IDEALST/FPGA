//=============================================================================
// 文件    : rgb565_split.v
// 功能    : RGB565 → 8bit R/G/B（复制高位补齐），1 拍流水
// 说明    : 5bit 扩 8bit 用 {v[4:0], v[4:2]}；6bit 扩 8bit 用 {v[5:0], v[5:4]}
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module rgb565_split (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] pix_data,
    input  wire        pix_valid,
    output reg  [7:0]  r,
    output reg  [7:0]  g,
    output reg  [7:0]  b,
    output reg         rgb_valid
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r <= 8'h00;
            g <= 8'h00;
            b <= 8'h00;
            rgb_valid <= 1'b0;
        end else begin
            r <= {pix_data[15:11], pix_data[13:11]};
            g <= {pix_data[10:5],  pix_data[6:5]};
            b <= {pix_data[4:0],   pix_data[2:0]};
            rgb_valid <= pix_valid;
        end
    end

endmodule

`default_nettype wire
