//=============================================================================
// 文件    : sccb_init_rom.v
// 功能    : OV5640 初始化寄存器表（1280×720 RGB565，DVP 输出）
// 说明    : 1) 本表为精简版（44 条），覆盖软复位、PLL、窗口、格式、ISP 输出等关键项；
//           2) 若上电后无图像或颜色异常，请用 OmniVision 官方《OV5640 Camera Module
//              Software Application Notes》中 720p RGB565 的完整序列替换本 case 内容，
//              结构不变：reg_addr 为 16bit 寄存器地址，reg_data 为 8bit 数值；
//           3) 设备地址 0x78（0x3C<<1）由 sccb_cfg 内部给出。
// 修改    : 增删条目后，务必同步修改 sccb_cfg 的 N_REG 参数。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module sccb_init_rom #(
    parameter integer N = 44
)(
    input  wire [5:0]  idx,
    output reg  [15:0] reg_addr,
    output reg  [7:0]  reg_data
);

    always @(*) begin
        // 默认值（越界时不会使用）
        reg_addr = 16'h3008;
        reg_data = 8'h02;

        case (idx)
        6'd0:  begin reg_addr = 16'h3103; reg_data = 8'h11; end  // 时钟来自 PAD
        6'd1:  begin reg_addr = 16'h3008; reg_data = 8'h82; end  // 软复位
        6'd2:  begin reg_addr = 16'h3103; reg_data = 8'h03; end  // 时钟来自 PLL
        6'd3:  begin reg_addr = 16'h3017; reg_data = 8'hFF; end  // 使能各通道输出
        6'd4:  begin reg_addr = 16'h3018; reg_data = 8'hFF; end
        6'd5:  begin reg_addr = 16'h3034; reg_data = 8'h1A; end  // PLL 电荷泵
        6'd6:  begin reg_addr = 16'h3035; reg_data = 8'h21; end  // PLL 控制
        6'd7:  begin reg_addr = 16'h3036; reg_data = 8'h54; end  // PLL 倍频
        6'd8:  begin reg_addr = 16'h3037; reg_data = 8'h13; end  // PLL 分频
        6'd9:  begin reg_addr = 16'h3108; reg_data = 8'h01; end  // 系统时钟分频
        6'd10: begin reg_addr = 16'h3630; reg_data = 8'h36; end  // 模拟电路
        6'd11: begin reg_addr = 16'h3631; reg_data = 8'h0E; end
        6'd12: begin reg_addr = 16'h3620; reg_data = 8'h66; end
        6'd13: begin reg_addr = 16'h3621; reg_data = 8'hE0; end
        6'd14: begin reg_addr = 16'h3708; reg_data = 8'hE6; end
        6'd15: begin reg_addr = 16'h3709; reg_data = 8'h52; end
        6'd16: begin reg_addr = 16'h370C; reg_data = 8'h03; end
        6'd17: begin reg_addr = 16'h3800; reg_data = 8'h00; end  // 开窗 X 起始
        6'd18: begin reg_addr = 16'h3801; reg_data = 8'h00; end
        6'd19: begin reg_addr = 16'h3802; reg_data = 8'h00; end  // 开窗 Y 起始
        6'd20: begin reg_addr = 16'h3803; reg_data = 8'h00; end
        6'd21: begin reg_addr = 16'h3804; reg_data = 8'h0A; end  // 有效区 X 结束 2623
        6'd22: begin reg_addr = 16'h3805; reg_data = 8'h3F; end
        6'd23: begin reg_addr = 16'h3806; reg_data = 8'h07; end  // 有效区 Y 结束 1951
        6'd24: begin reg_addr = 16'h3807; reg_data = 8'h9F; end
        6'd25: begin reg_addr = 16'h3808; reg_data = 8'h05; end  // 输出宽 1280
        6'd26: begin reg_addr = 16'h3809; reg_data = 8'h00; end
        6'd27: begin reg_addr = 16'h380A; reg_data = 8'h02; end  // 输出高 720
        6'd28: begin reg_addr = 16'h380B; reg_data = 8'hD0; end
        6'd29: begin reg_addr = 16'h380C; reg_data = 8'h0A; end  // HTS = 2700
        6'd30: begin reg_addr = 16'h380D; reg_data = 8'h8C; end
        6'd31: begin reg_addr = 16'h380E; reg_data = 8'h02; end  // VTS = 750
        6'd32: begin reg_addr = 16'h380F; reg_data = 8'hEE; end
        6'd33: begin reg_addr = 16'h3810; reg_data = 8'h00; end  // 水平偏移
        6'd34: begin reg_addr = 16'h3811; reg_data = 8'h08; end
        6'd35: begin reg_addr = 16'h3812; reg_data = 8'h00; end  // 垂直偏移
        6'd36: begin reg_addr = 16'h3813; reg_data = 8'h02; end
        6'd37: begin reg_addr = 16'h3820; reg_data = 8'h46; end  // 翻转/镜像
        6'd38: begin reg_addr = 16'h3821; reg_data = 8'h00; end
        6'd39: begin reg_addr = 16'h4001; reg_data = 8'h02; end  // 黑电平
        6'd40: begin reg_addr = 16'h4300; reg_data = 8'h6F; end  // 输出格式 RGB565
        6'd41: begin reg_addr = 16'h501F; reg_data = 8'h03; end  // ISP 输出 RGB
        6'd42: begin reg_addr = 16'h4740; reg_data = 8'h21; end  // VSYNC 极性
        6'd43: begin reg_addr = 16'h3008; reg_data = 8'h02; end  // 退出待机，开始出图
        default: begin reg_addr = 16'h3008; reg_data = 8'h02; end
        endcase
    end

endmodule

`default_nettype wire
