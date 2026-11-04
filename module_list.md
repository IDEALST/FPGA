# 模块清单与接口说明

所有模块均为 Verilog-2001 可综合代码，无第三方 IP（MMCM / ODDR / OBUFDS / BUFG 为 Xilinx 原语）。

## 1. 顶层 `sobel_top.v`

| 端口 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| clk_50m | 输入 | 1 | 板载 50 MHz |
| rst_n | 输入 | 1 | 复位，低有效 |
| key[1:0] | 输入 | 2 | 阈值 +/− |
| cam_pclk / cam_href / cam_vsync | 输入 | 1 | DVP 时序 |
| cam_data[7:0] | 输入 | 8 | RGB565 字节流 |
| sccb_scl / sccb_sda | 双向 | 1 | 摄像头配置 |
| cam_xclk / cam_rst_n | 输出 | 1 | 摄像头控制（PWDN 由模组内部下拉） |
| tmds_d_p[2:0] / tmds_d_n[2:0] | 输出 | 3 | HDMI 三通道差分 |
| tmds_clk_p / tmds_clk_n | 输出 | 1 | HDMI 时钟差分 |
| uart_tx | 输出 | 1 | 调试串口 |
| led_locked / led_frame | 输出 | 1 | 状态指示（可删） |

参数：`H_ACTIVE / H_FP / H_SYNC / H_BP / V_ACTIVE / V_FP / V_SYNC / V_BP / V_TOTAL / TH_INIT / TH_STEP / SIM_MODE`

## 2. 模块一览

| 模块 | 文件 | 时钟域 | 延迟 | 关键功能 |
|---|---|---|---|---|
| clk_rst_gen | clk_rst_gen.v | — | — | MMCM 三路输出 + 复位同步；SIM_MODE=1 为行为模型 |
| sccb_cfg | sccb_cfg.v | clk_pix | 44×~0.4ms | SCCB 主机，16bit 寄存器地址，100 kHz |
| sccb_init_rom | sccb_init_rom.v | — | 组合 | 44 条 OV5640 初始化表 |
| dvp_capture | dvp_capture.v | cam_pclk → clk_pix | FIFO 2~3 拍 | 字节拼接、VSYNC/HREF 跨域、帧/行起始脉冲 |
| async_fifo | async_fifo.v | 双时钟 | 2 | 格雷码指针，16bit × 256 |
| vid_sync | vid_sync.v | 任意 | 2 | 两级同步 + 边沿检测 |
| pixel_pipe | pixel_pipe.v | clk_pix | 见下 | 四级流水封装 |
| rgb565_split | rgb565_split.v | clk_pix | 1 | RGB565 → RGB888（复制高位） |
| gray_conv | gray_conv.v | clk_pix | 3 | (77R+150G+29B)>>8，纯移位加法 |
| line_buf_3x3 | line_buf_3x3.v | clk_pix | 2 | 双行缓存 + 9 寄存器窗口 |
| sobel_conv | sobel_conv.v | clk_pix | 2 | Gx/Gy 并行，±1/±2 |
| thresh_bin | thresh_bin.v | clk_pix | 1 | \|Gx\|+\|Gy\| → 8bit → 阈值比较 |
| video_out | video_out.v | clk_pix / clk_5x | — | 对齐 FIFO + 3 通道 TMDS |
| hdmi_timing | hdmi_timing.v | clk_pix | 1 | 1280×720 行场时序 |
| tmds_encoder | tmds_encoder.v | clk_pix | 1 | 8b/10b + DC 平衡 |
| tmds_serdes | tmds_serdes.v | clk_5x | — | 10:1 DDR 串行化 + OBUFDS |
| dbg_ctrl | dbg_ctrl.v | clk_pix | — | 阈值按键、帧率、串口报文 |
| key_debounce | key_debounce.v | clk_pix | 20 ms | 消抖，按下出单周期脉冲 |
| frame_stat | frame_stat.v | clk_pix | 1 s | 帧率 + BCD 帧计数 |
| uart_tx | uart_tx.v | clk_pix | — | 115200 8N1 |

## 3. 流水线延迟核算

| 级 | 附加延迟 |
|---|---|
| 采集 FIFO | 2~3 拍（取决于 FIFO 水位） |
| rgb565_split | 1 拍 |
| gray_conv | 3 拍 |
| line_buf_3x3 | 2 行 + 2 拍 |
| sobel_conv | 2 拍 |
| thresh_bin | 1 拍 |
| **合计** | **2 行 + 9 拍**（约 2×1650 + 9 ≈ 3309 个像素周期 ≈ 44.6 µs @74.17 MHz） |

## 4. 数据格式

- 像素：RGB565，高字节在前，`{R[4:0], G[5:0], B[4:0]}` 由两字节拼成 16bit
- 灰度：8bit，`(77R+150G+29B)>>8`
- 梯度：11bit 有符号，范围 −1020 ~ +1020
- 判决：`(|Gx|+|Gy|)>>3 >= threshold` → 输出白色
- 串口报文：`FPS=xx TH=yyy FR=nnnn\r\n`（23 字节，每秒一次）

## 5. 与文档图 2-11 的对应

| 图 2-11 中的模块 | 代码文件 |
|---|---|
| clk_rst_gen | clk_rst_gen.v |
| sccb_cfg | sccb_cfg.v（+ sccb_init_rom.v） |
| dvp_capture（含 vid_sync） | dvp_capture.v + vid_sync.v |
| pixel_pipe（rgb565_split / gray_conv / line_buf_3x3 / sobel_conv / thresh_bin） | pixel_pipe.v 及 5 个子模块 |
| video_out（hdmi_timing / tmds_encoder） | video_out.v + hdmi_timing.v + tmds_encoder.v + tmds_serdes.v |
| dbg_ctrl（key_debounce / uart_tx） | dbg_ctrl.v + key_debounce.v + uart_tx.v（+ frame_stat.v） |
