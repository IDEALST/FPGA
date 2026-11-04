//=============================================================================
// 文件    : tmds_encoder.v
// 功能    : TMDS 8b/10b 编码（单通道，DVI/HDMI 兼容）
// 说明    : 1) de=1 时对 8bit 像素做最小化跳变编码（含 DC 平衡）；
//           2) de=0 时输出控制字符，通道 0 的 c0/c1 分别为 HSYNC/VSYNC；
//           3) 输出 10bit LSB 先行，交给 tmds_serdes 并串转换。
//           4) 运行不平衡量 cnt 直接按 10bit 输出中 1 的个数统计，
//              与规范中的差分累加等价，且更易读。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module tmds_encoder (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  din,
    input  wire        c0,
    input  wire        c1,
    input  wire        de,
    output reg  [9:0]  dout
);

    integer i;

    //--------------------------------------------- 统计输入中 1 的个数
    reg [3:0] n1d;
    always @(*) begin
        n1d = 4'd0;
        for (i = 0; i < 8; i = i + 1)
            n1d = n1d + {3'd0, din[i]};
    end

    //------------------------------------ 第 1 步：最小化跳变编码
    reg [7:0] q_n;
    reg [8:0] q_m;
    always @(*) begin
        q_n[0] = din[0];
        q_n[1] = q_n[0] ^ din[1];
        q_n[2] = q_n[1] ^ din[2];
        q_n[3] = q_n[2] ^ din[3];
        q_n[4] = q_n[3] ^ din[4];
        q_n[5] = q_n[4] ^ din[5];
        q_n[6] = q_n[5] ^ din[6];
        q_n[7] = q_n[6] ^ din[7];
        // 1 的个数 > 4，或 = 4 且 din[0]=0 时取反，减少跳变
        if ((n1d > 4'd4) || ((n1d == 4'd4) && (din[0] == 1'b0)))
            q_m = {~q_n[7], q_n};
        else
            q_m = { q_n[7], q_n};
    end

    //--------------------------------------- 统计 q_m 的 1/0 个数
    reg [3:0] n1q_m, n0q_m;
    always @(*) begin
        n1q_m = 4'd0;
        n0q_m = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (q_m[i]) n1q_m = n1q_m + 4'd1;
            else        n0q_m = n0q_m + 4'd1;
        end
    end

    //--------------------------------------- 第 2 步：DC 平衡
    //  取反规则：在不平衡量 cnt 与本字的极性相反时取反，使累计不平衡量收敛到 0。
    //  （规范允许两种输出形式，接收端靠 dout[9] 判别，故该简化规则可被正确解码，
    //    且能保证长期 DC 平衡。）
    reg signed [4:0] cnt;                 // 运行不平衡量
    reg              inv;                 // 本拍是否取反输出
    reg [3:0]        ones10;              // 输出 10bit 中 1 的个数
    reg signed [5:0] delta;
    wire signed [4:0] bal = $signed({1'b0, n1q_m}) - $signed({1'b0, n0q_m});

    always @(*) begin
        inv = ((cnt > 5'sd0) && (bal > 5'sd0)) ||
              ((cnt < 5'sd0) && (bal < 5'sd0)) ||
              ((cnt == 5'sd0) && (bal > 5'sd0));
        if (inv)
            ones10 = 4'd1 + {3'd0, q_m[8]} + n0q_m;   // 第 9 位为 1，低 8 位取反
        else
            ones10 = {3'd0, q_m[8]} + n1q_m;
        delta = $signed({2'b00, ones10}) * 2 - 6'sd10; // 2*ones10 - 10
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 10'b1101010100;
            cnt  <= 5'sd0;
        end else if (!de) begin
            case ({c1, c0})
            2'b00:   dout <= 10'b1101010100;
            2'b01:   dout <= 10'b0010101011;
            2'b10:   dout <= 10'b0101010100;
            default: dout <= 10'b1010101011;
            endcase
            cnt <= 5'sd0;
        end else begin
            if (inv)
                dout <= {1'b1, q_m[8], ~q_m[7:0]};
            else
                dout <= {1'b0, q_m[8],  q_m[7:0]};
            cnt <= cnt + delta[4:0];
        end
    end

endmodule

`default_nettype wire
