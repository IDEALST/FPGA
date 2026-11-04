#=============================================================================
# 文件    : sobel_top.xdc
# 工程    : 基于 Artix-7 的实时 Sobel 边缘检测加速系统
# 内容    : 时钟、异步时钟组、输入输出延时、IO 电平标准、位流配置
# 注意    : 1) 本文件不含 PACKAGE_PIN，引脚请在 pin_assign_example.xdc 的格式下
#              按 ACX720 原理图逐条填写，或直接用 Vivado 的 I/O Planning 分配；
#           2) 未分配引脚时，综合可以通过，Implementation 会报 unplaced IO 错误。
#=============================================================================

#--------------------------------------------------------------- 主时钟
create_clock -name clk_50m -period 20.000 [get_ports clk_50m]

#----------------------------------------------------- 摄像头像素时钟
# OV5640 的 PCLK 由模组内部 PLL 从 XCLK 产生，与 FPGA 像素时钟异步，
# 这里按 40ns（25MHz）约束，实际值取决于 sccb_init_rom 中的 PLL 配置。
create_clock -name cam_pclk -period 40.000 [get_ports cam_pclk]

#----------------------------------------------------- 异步时钟组
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks clk_50m] \
    -group [get_clocks cam_pclk]

#----------------------------------------------- 采集侧输入延时
set_input_delay -clock cam_pclk -max 8.000 [get_ports {cam_data[*] cam_href cam_vsync}]
set_input_delay -clock cam_pclk -min 2.000 [get_ports {cam_data[*] cam_href cam_vsync}]

#----------------------------------------------- TMDS 输出延时
set clk_5x_clk [get_clocks -include_generated_clocks -of_objects \
    [get_pins -hierarchical -filter {NAME =~ *u_mmcm/CLKOUT1}]]

if {[llength $clk_5x_clk] > 0} {
    set_output_delay -clock $clk_5x_clk -max 0.800 \
        [get_ports {tmds_d_p[*] tmds_d_n[*] tmds_clk_p tmds_clk_n}]
    set_output_delay -clock $clk_5x_clk -min -0.800 \
        [get_ports {tmds_d_p[*] tmds_d_n[*] tmds_clk_p tmds_clk_n}]
}

#----------------------------------------------- IO 电平标准
set_property IOSTANDARD LVCMOS33 [get_ports {clk_50m rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {key[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_pclk cam_href cam_vsync cam_data[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cam_xclk cam_rst_n}]
set_property IOSTANDARD LVCMOS33 [get_ports {sccb_scl sccb_sda}]
set_property IOSTANDARD LVCMOS33 [get_ports {uart_tx led_locked led_frame}]
set_property IOSTANDARD TMDS_33  [get_ports {tmds_d_p[*] tmds_d_n[*] tmds_clk_p tmds_clk_n}]

# SCCB 开漏：引脚属性按需保留上拉（多数板卡已有 4.7k 外部上拉）
# set_property PULLUP true [get_ports {sccb_scl sccb_sda}]

#----------------------------------------------- 位流与配置
set_property CFGBVS VCCO      [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
# 以下两项按 ACX720 的 QSPI 启动方式启用（若只用 JTAG 下载可注释）
# set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
# set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
# set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
