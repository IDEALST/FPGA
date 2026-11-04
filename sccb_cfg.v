//=============================================================================
// 文件    : sccb_cfg.v
// 功能    : SCCB（兼容 I2C）主机，上电后按 ROM 表顺序配置 OV5640
//           OV5640 使用 16bit 寄存器地址：设备地址 → 地址高字节 → 地址低字节 → 数据
// 时序    : SCL ≈ 100kHz（74.1667MHz / 742），每位 4 个相位，第 9 拍为 ACK
//           总线为开漏：只在需要拉低时驱动，其余时间高阻，由上拉电阻拉高
// 输出    : cfg_done 拉高表示整表写完
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module sccb_cfg #(
    parameter integer CLK_HZ  = 74166667,
    parameter integer SCL_HZ  = 100000,
    parameter integer N_REG   = 44          // ROM 条目数，需与 sccb_init_rom 一致
)(
    input  wire clk,
    input  wire rst_n,
    inout  wire scl,
    inout  wire sda,
    output reg  cfg_done
);

    localparam integer DIV = (CLK_HZ / (SCL_HZ * 4)) > 1 ? (CLK_HZ / (SCL_HZ * 4)) : 2;
    localparam [15:0]  DIV16   = DIV;
    localparam [5:0]   N_REG6  = N_REG;

    //---------------------------------------------------------- ROM
    wire [5:0]  rom_idx;
    wire [15:0] rom_addr;
    wire [7:0]  rom_data;

    sccb_init_rom #(.N(N_REG)) u_rom (
        .idx      (rom_idx),
        .reg_addr (rom_addr),
        .reg_data (rom_data)
    );

    //-------------------------------------------------------- 分频
    reg [15:0] div_cnt;
    wire       tick = (div_cnt == DIV16 - 16'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)      div_cnt <= 16'd0;
        else if (tick)   div_cnt <= 16'd0;
        else             div_cnt <= div_cnt + 16'd1;
    end

    //------------------------------------------------------- 状态机
    localparam [3:0] S_IDLE  = 4'd0,
                     S_START = 4'd1,
                     S_ADDR  = 4'd2,     // 设备地址 0x78
                     S_AH    = 4'd3,     // 寄存器地址高字节
                     S_AL    = 4'd4,     // 寄存器地址低字节
                     S_DAT   = 4'd5,     // 数据
                     S_ACK   = 4'd6,     // 应答位
                     S_STOP  = 4'd7,
                     S_DONE  = 4'd8;

    reg [3:0]  state;
    reg [1:0]  phase;            // 0..3
    reg [3:0]  bitc;             // 0..8（第 9 拍为 ACK）
    reg [7:0]  shreg;
    reg        scl_o, sda_o;
    reg [5:0]  idx;

    assign rom_idx = idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            phase    <= 2'd0;
            bitc     <= 4'd0;
            shreg    <= 8'h00;
            scl_o    <= 1'b1;
            sda_o    <= 1'b1;
            idx      <= 6'd0;
            cfg_done <= 1'b0;
        end else if (tick) begin
            phase <= phase + 2'd1;

            case (state)
            //----------------------------------------------- 空闲
            S_IDLE: begin
                scl_o  <= 1'b1;
                sda_o  <= 1'b1;
                if (phase == 2'd3) begin
                    idx      <= 6'd0;
                    cfg_done <= 1'b0;
                    state    <= S_START;
                end
            end

            //--------------------------------------------- 起始位
            S_START: begin
                case (phase)
                2'd0: begin scl_o <= 1'b1; sda_o <= 1'b1; end
                2'd1: begin scl_o <= 1'b1; sda_o <= 1'b0; end   // SCL 高时 SDA 下降
                2'd2: begin scl_o <= 1'b0; sda_o <= 1'b0; end
                2'd3: begin
                    scl_o <= 1'b0;
                    shreg <= 8'h78;                              // 0x3C<<1 | W
                    bitc  <= 4'd0;
                    state <= S_ADDR;
                end
                endcase
            end

            //--------------------------------- 发送 8bit + 第 9 拍 ACK
            S_ADDR, S_AH, S_AL, S_DAT: begin
                case (phase)
                2'd0: begin
                    scl_o <= 1'b0;
                    sda_o <= (bitc == 4'd8) ? 1'b1 : shreg[7];    // ACK 拍释放 SDA
                end
                2'd1: scl_o <= 1'b1;
                2'd2: scl_o <= 1'b1;
                2'd3: begin
                    scl_o <= 1'b0;
                    if (bitc == 4'd8) begin
                        bitc <= 4'd0;
                        case (state)
                        S_ADDR: begin shreg <= rom_addr[15:8]; state <= S_AH;   end
                        S_AH:   begin shreg <= rom_addr[7:0];  state <= S_AL;   end
                        S_AL:   begin shreg <= rom_data;       state <= S_DAT;  end
                        default: state <= S_STOP;
                        endcase
                    end else begin
                        shreg <= {shreg[6:0], 1'b0};
                        bitc  <= bitc + 4'd1;
                    end
                end
                endcase
            end

            //--------------------------------------------- 停止位
            S_STOP: begin
                case (phase)
                2'd0: begin scl_o <= 1'b0; sda_o <= 1'b0; end
                2'd1: begin scl_o <= 1'b1; sda_o <= 1'b0; end
                2'd2: begin scl_o <= 1'b1; sda_o <= 1'b1; end     // SCL 高时 SDA 上升
                2'd3: begin
                    if (idx == N_REG6 - 6'd1)
                        state <= S_DONE;
                    else begin
                        idx   <= idx + 6'd1;
                        state <= S_START;
                    end
                end
                endcase
            end

            //----------------------------------------------- 完成
            S_DONE: begin
                cfg_done <= 1'b1;
                scl_o    <= 1'b1;
                sda_o    <= 1'b1;
            end

            default: state <= S_IDLE;
            endcase
        end
    end

    // 开漏：仅驱动低电平
    assign scl = (scl_o == 1'b0) ? 1'b0 : 1'bz;
    assign sda = (sda_o == 1'b0) ? 1'b0 : 1'bz;

endmodule

`default_nettype wire
