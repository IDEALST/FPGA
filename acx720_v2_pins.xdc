#=============================================================================
# 文件    : acx720_v2_pins.xdc
# 板卡    : ACX720-V2（XC7A35T-2FGG484）
# 依据    : ACX720-V2-SCH.pdf
#           · 01_7A35T_FPGA_IO.SchDoc        （Bank 14 / 15 / 34、50MHz、UART、LED）
#           · 02_7A35T_FPGA_IO_ConfigBank.SchDoc（Bank 16 / 35、摄像头、HDMI、按键）
#           · 08_HDMI2.SchDoc                （HDMI2 连接器与 49.9Ω 串阻）
#           · 10_Switch_Key_Led.SchDoc       （S0~S4 按键、LED0~7、LVC244 缓冲）
# 说明    : 1) 摄像头走 GPIO0 排针（DVP 8bit + SCCB），HDMI 使用板上 HDMI2 口；
#           2) 所有用到的 Bank 均为 3.3V（Bank 14/15/16/35），故统一 LVCMOS33；
#              HDMI 差分对用 TMDS_33（Bank 35 的 VCCO_35 接 VCC3V3）；
#           3) S0~S4 经 74LVC244 缓冲，按下为低电平；
#           4) LED0~LED7 为「FPGA 高电平点亮」（限流电阻 2.49kΩ 在阳极侧）；
#           5) 若换用 HDMI1 口，请改接 HDMI1_* 网络（E19/D19/L3/K3/M3/M2/L5/L4 等）。
#=============================================================================

#-------------------------------------------------- 时钟 / 复位 / 按键
set_property PACKAGE_PIN Y18 [get_ports clk_50m]        ;# FPGA_GCLK1，Bank14 MRCC，50M 有源晶振经 R5=33Ω
set_property PACKAGE_PIN F15 [get_ports rst_n]          ;# S0（按下为低）
set_property PACKAGE_PIN A20 [get_ports {key[0]}]       ;# S1  阈值 +
set_property PACKAGE_PIN B20 [get_ports {key[1]}]       ;# S2  阈值 -

#-------------------------------------------------- 摄像头 DVP（GPIO0 排针）
set_property PACKAGE_PIN B1  [get_ports cam_pclk]       ;# CMOS_PCLK
set_property PACKAGE_PIN A1  [get_ports cam_href]       ;# CMOS_HREF
set_property PACKAGE_PIN B2  [get_ports cam_vsync]      ;# CMOS_VSYNC
set_property PACKAGE_PIN J2  [get_ports {cam_data[0]}]  ;# CMOS_D0
set_property PACKAGE_PIN J1  [get_ports {cam_data[1]}]  ;# CMOS_D1
set_property PACKAGE_PIN G1  [get_ports {cam_data[2]}]  ;# CMOS_D2
set_property PACKAGE_PIN H2  [get_ports {cam_data[3]}]  ;# CMOS_D3
set_property PACKAGE_PIN F1  [get_ports {cam_data[4]}]  ;# CMOS_D4
set_property PACKAGE_PIN G2  [get_ports {cam_data[5]}]  ;# CMOS_D5
set_property PACKAGE_PIN D1  [get_ports {cam_data[6]}]  ;# CMOS_D6
set_property PACKAGE_PIN E1  [get_ports {cam_data[7]}]  ;# CMOS_D7
set_property PACKAGE_PIN M17 [get_ports cam_xclk]       ;# CMOS_XCLK（FPGA 输出给模组）
set_property PACKAGE_PIN N20 [get_ports cam_rst_n]      ;# CMOS_RST
set_property PACKAGE_PIN M20 [get_ports sccb_scl]       ;# CMOS_SCLK
set_property PACKAGE_PIN L18 [get_ports sccb_sda]       ;# CMOS_SDA

#-------------------------------------------------- HDMI2（TMDS 差分对）
set_property PACKAGE_PIN E2  [get_ports {tmds_d_p[0]}]  ;# HDMI2_D0_P  蓝
set_property PACKAGE_PIN D2  [get_ports {tmds_d_n[0]}]  ;# HDMI2_D0_N
set_property PACKAGE_PIN F3  [get_ports {tmds_d_p[1]}]  ;# HDMI2_D1_P  绿
set_property PACKAGE_PIN E3  [get_ports {tmds_d_n[1]}]  ;# HDMI2_D1_N
set_property PACKAGE_PIN H3  [get_ports {tmds_d_p[2]}]  ;# HDMI2_D2_P  红
set_property PACKAGE_PIN G3  [get_ports {tmds_d_n[2]}]  ;# HDMI2_D2_N
set_property PACKAGE_PIN H4  [get_ports tmds_clk_p]     ;# HDMI2_CLK_P
set_property PACKAGE_PIN G4  [get_ports tmds_clk_n]     ;# HDMI2_CLK_N

#-------------------------------------------------- SCCB 开漏上拉
# 模组内部一般有 4.7k 上拉；这里再开 FPGA 弱上拉兜底（不影响正常通信）
set_property PULLUP true [get_ports {sccb_scl sccb_sda}]

#-------------------------------------------------- 串口 / 指示灯
set_property PACKAGE_PIN M15 [get_ports uart_tx]        ;# FPGA_UART_TX（CH340 的 RXD）
set_property PACKAGE_PIN M22 [get_ports led_locked]     ;# LED0（高电平点亮）
set_property PACKAGE_PIN N22 [get_ports led_frame]      ;# LED1

#=============================================================================
# 备注：
#   1) 摄像头模组若通过 20P FPC 转接板接入 GPIO0 排针，请确认转接板的
#      PCLK/HREF/VSYNC/D[7:0]/SCL/SDA/RST/XCLK 与上表一一对应；
#   2) cam_pwdn 已在 RTL 中去掉（模组 PWDN 在模块内部下拉），如需控制，
#      可接到 GPIO0 排针上任意空闲 IO 并在顶层恢复该端口；
#   3) 若 Vivado 报 VCCO 一致性错误，说明该 Bank 实际电压与本文件假设不同，
#      把对应端口的 IOSTANDARD 改成实测电压即可（管脚号不变）。
#=============================================================================
