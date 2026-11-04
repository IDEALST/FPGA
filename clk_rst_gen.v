//=============================================================================
// 文件    : clk_rst_gen.v
// 功能    : 时钟与复位生成
//           50MHz 参考 → MMCM → 74.1667MHz(像素) / 370.83MHz(串行) / 23.99MHz(摄像头 XCLK)
// 说明    : 50MHz 与 74.25MHz 互质（74.25 = 27*11/4），MMCM 无法在 600~1200MHz 的
//           VCO 范围内精确合成 74.25MHz。本工程取 VCO = 1112.5MHz：
//               像素时钟  = 1112.5 / 15      = 74.1667MHz（偏差 -0.11%）
//               串行时钟  = 1112.5 / 3       = 370.833MHz（严格 5 倍关系）
//               摄像头时钟 = 1112.5 / 46.375  = 23.989MHz
//           若板上另有 74.25MHz 晶振，把 clk_50m 换成它后按注释修改参数即可。
//           SIM_MODE=1 时用行为级模型代替 MMCM，便于纯 Verilog 仿真工具跑顶层。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module clk_rst_gen #(
    parameter integer SIM_MODE = 0
)(
    input  wire clk_50m,
    input  wire rst_n_in,
    output wire clk_pix,
    output wire clk_5x,
    output wire clk_xclk,
    output wire locked,
    output wire rst_n_pix
);

    generate
    //---------------------------------------------------- 行为级模型
    if (SIM_MODE != 0) begin : g_sim
        assign clk_pix  = clk_50m;
        assign clk_5x   = clk_50m;
        assign clk_xclk = clk_50m;
        assign locked   = 1'b1;
    end
    //------------------------------------------------------ 真实 MMCM
    else begin : g_real
        wire clkfb;
        wire clk_pix_raw;
        wire clk_5x_raw;
        wire clk_xclk_raw;

        MMCME2_BASE #(
            .BANDWIDTH          ("OPTIMIZED"),
            .CLKFBOUT_MULT_F    (22.250),      // VCO = 1112.5MHz
            .CLKFBOUT_PHASE     (0.000),
            .CLKIN1_PERIOD      (20.000),      // 50MHz
            .CLKOUT0_DIVIDE_F   (46.375),      // 23.989MHz → 摄像头 XCLK
            .CLKOUT0_DUTY_CYCLE (0.500),
            .CLKOUT0_PHASE      (0.000),
            .CLKOUT1_DIVIDE     (3),           // 370.833MHz → TMDS 串行时钟
            .CLKOUT1_DUTY_CYCLE (0.500),
            .CLKOUT1_PHASE      (0.000),
            .CLKOUT2_DIVIDE     (15),          // 74.1667MHz → 像素时钟
            .CLKOUT2_DUTY_CYCLE (0.500),
            .CLKOUT2_PHASE      (0.000),
            .CLKOUT3_DIVIDE     (1),
            .CLKOUT4_DIVIDE     (1),
            .CLKOUT5_DIVIDE     (1),
            .CLKOUT6_DIVIDE     (1),
            .DIVCLK_DIVIDE      (1),
            .REF_JITTER1        (0.010),
            .STARTUP_WAIT       ("FALSE")
        ) u_mmcm (
            .CLKOUT0   (clk_xclk_raw),
            .CLKOUT0B  (),
            .CLKOUT1   (clk_5x_raw),
            .CLKOUT1B  (),
            .CLKOUT2   (clk_pix_raw),
            .CLKOUT2B  (),
            .CLKOUT3   (),
            .CLKOUT3B  (),
            .CLKOUT4   (),
            .CLKOUT5   (),
            .CLKOUT6   (),
            .CLKFBOUT  (clkfb),
            .CLKFBOUTB (),
            .CLKFBIN   (clkfb),
            .CLKIN1    (clk_50m),
            .CLKINSEL  (1'b1),
            .DADDR     (7'h00),
            .DCLK      (1'b0),
            .DEN       (1'b0),
            .DI        (16'h0000),
            .DO        (),
            .DRDY      (),
            .PSCLK     (1'b0),
            .PSEN      (1'b0),
            .PSINCDEC  (1'b0),
            .PSDONE    (),
            .LOCKED    (locked),
            .PWRDWN    (1'b0),
            .RST       (~rst_n_in)
        );

        BUFG u_bufg_pix  (.I(clk_pix_raw),  .O(clk_pix));
        BUFG u_bufg_5x   (.I(clk_5x_raw),   .O(clk_5x));
        BUFG u_bufg_xclk (.I(clk_xclk_raw), .O(clk_xclk));
    end
    endgenerate

    //----------------------------------------------- 复位同步
    reg [2:0] rst_sync;

    always @(posedge clk_pix or negedge rst_n_in) begin
        if (!rst_n_in)
            rst_sync <= 3'b000;
        else if (!locked)
            rst_sync <= 3'b000;
        else
            rst_sync <= {rst_sync[1:0], 1'b1};
    end

    assign rst_n_pix = rst_sync[2];

endmodule

`default_nettype wire
