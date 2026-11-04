//=============================================================================
// 文件    : uart_tx.v
// 功能    : 8N1 串口发送，默认 115200bps（74.1667MHz / 644）
// 时序    : 起始位 0 → 8bit 数据（LSB 先行）→ 停止位 1
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module uart_tx #(
    parameter integer CLK_HZ = 74166667,
    parameter integer BAUD   = 115200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] din,
    input  wire       din_valid,
    output reg        tx,
    output reg        busy
);

    localparam integer DIV   = (CLK_HZ / BAUD) > 1 ? (CLK_HZ / BAUD) : 2;
    localparam [15:0]  DIV16 = DIV;

    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] baud_cnt;
    reg [2:0]  bitc;
    reg [7:0]  shreg;

    wire baud_tick = (baud_cnt == DIV16 - 16'd1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            baud_cnt <= 16'd0;
            bitc     <= 3'd0;
            shreg    <= 8'h00;
            tx       <= 1'b1;
            busy     <= 1'b0;
        end else begin
            case (state)
            S_IDLE: begin
                tx   <= 1'b1;
                busy <= 1'b0;
                if (din_valid) begin
                    shreg    <= din;
                    busy     <= 1'b1;
                    baud_cnt <= 16'd0;
                    state    <= S_START;
                end
            end

            S_START: begin
                tx <= 1'b0;
                if (baud_tick) begin
                    baud_cnt <= 16'd0;
                    bitc     <= 3'd0;
                    state    <= S_DATA;
                end else begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
            end

            S_DATA: begin
                tx <= shreg[0];
                if (baud_tick) begin
                    baud_cnt <= 16'd0;
                    shreg    <= {1'b0, shreg[7:1]};
                    if (bitc == 3'd7) begin
                        bitc  <= 3'd0;
                        state <= S_STOP;
                    end else begin
                        bitc <= bitc + 3'd1;
                    end
                end else begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
            end

            S_STOP: begin
                tx <= 1'b1;
                if (baud_tick) begin
                    baud_cnt <= 16'd0;
                    state    <= S_IDLE;
                end else begin
                    baud_cnt <= baud_cnt + 16'd1;
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
