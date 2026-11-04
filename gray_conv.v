//=============================================================================
// 文件    : gray_conv.v
// 功能    : RGB888 → 灰度，3 级流水
// 公式    : Gray = (77*R + 150*G + 29*B) >> 8
//           77/150/29 是 0.299/0.587/0.114 的 8bit 定点近似，最大误差 ≤ 1 个灰度级
// 实现    : 全程移位加法，无乘法器、无 DSP
//           77R  = (R<<6) + (R<<3) + R
//           150G = (G<<7) + (G<<4) + (G<<2) + (G<<1)
//           29B  = (B<<4) + (B<<3) + (B<<2) + B
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module gray_conv (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] r,
    input  wire [7:0] g,
    input  wire [7:0] b,
    input  wire       din_valid,
    output reg  [7:0] gray,
    output reg        dout_valid
);

    //------------------------------------------------- 第 1 级：部分积
    reg [14:0] pr;
    reg [15:0] pg;
    reg [12:0] pb;
    reg        v1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pr <= 15'd0;
            pg <= 16'd0;
            pb <= 13'd0;
            v1 <= 1'b0;
        end else begin
            pr <= ({7'd0, r} << 6) + ({7'd0, r} << 3) + {7'd0, r};
            pg <= ({6'd0, g} << 7) + ({6'd0, g} << 4) + ({6'd0, g} << 2) + ({6'd0, g} << 1);
            pb <= ({8'd0, b} << 4) + ({8'd0, b} << 3) + ({8'd0, b} << 2) + {8'd0, b};
            v1 <= din_valid;
        end
    end

    //------------------------------------------------- 第 2 级：求和
    reg [16:0] sum;
    reg        v2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 17'd0;
            v2  <= 1'b0;
        end else begin
            sum <= {2'd0, pr} + {1'd0, pg} + {4'd0, pb};
            v2  <= v1;
        end
    end

    //--------------------------------------------- 第 3 级：右移 + 饱和
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gray       <= 8'h00;
            dout_valid <= 1'b0;
        end else begin
            if (sum[16])
                gray <= 8'hFF;                 // 溢出饱和
            else
                gray <= sum[15:8];
            dout_valid <= v2;
        end
    end

endmodule

`default_nettype wire
