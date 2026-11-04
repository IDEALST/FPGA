//=============================================================================
// 文件    : dbg_ctrl.v
// 功能    : 调试与外设控制
//           1) 按键消抖 → 阈值 ±（步进 8，范围 0~255）
//           2) 帧率统计
//           3) 每秒通过 UART 上报："FPS=xx TH=yyy FR=nnnn\r\n"（115200 8N1）
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module dbg_ctrl #(
    parameter integer CLK_HZ  = 74166667,
    parameter integer TH_INIT = 64,
    parameter integer TH_STEP = 8
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] key,
    input  wire       frame_start,
    output reg  [7:0] threshold,
    output wire       uart_tx,
    output reg        led_frame
);

    //-------------------------------------------------------- 按键
    wire [1:0] press;

    key_debounce #(
        .CLK_HZ (CLK_HZ),
        .MS     (20),
        .NKEY   (2)
    ) u_key (
        .clk  (clk),
        .rst_n(rst_n),
        .key  (key),
        .press(press)
    );

    //-------------------------------------------------------- 阈值
    localparam [7:0] STEP = TH_STEP;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            threshold <= TH_INIT;
        end else begin
            if (press[0]) begin
                if (threshold <= 8'hFF - STEP)
                    threshold <= threshold + STEP;
                else
                    threshold <= 8'hFF;
            end else if (press[1]) begin
                if (threshold >= STEP)
                    threshold <= threshold - STEP;
                else
                    threshold <= 8'h00;
            end
        end
    end

    //-------------------------------------------------------- 帧统计
    wire [7:0] fps;
    wire [3:0] fd3, fd2, fd1, fd0;
    wire       sec_tick;

    frame_stat #(
        .CLK_HZ (CLK_HZ)
    ) u_frame_stat (
        .clk        (clk),
        .rst_n      (rst_n),
        .frame_start(frame_start),
        .fps        (fps),
        .fd3        (fd3),
        .fd2        (fd2),
        .fd1        (fd1),
        .fd0        (fd0),
        .sec_tick   (sec_tick)
    );

    //------------------------------------------------- 报文缓冲
    reg [7:0] buf0, buf1, buf2, buf3, buf4, buf5, buf6, buf7;
    reg [7:0] buf8, buf9, buf10, buf11, buf12, buf13, buf14, buf15;
    reg [7:0] buf16, buf17, buf18, buf19, buf20, buf21, buf22;

    wire [3:0] fps_t  = fps / 8'd10;
    wire [3:0] fps_u  = fps % 8'd10;
    wire [3:0] th_h   = threshold / 8'd100;
    wire [3:0] th_t   = (threshold % 8'd100) / 8'd10;
    wire [3:0] th_u   = threshold % 8'd10;


    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            buf0  <= "F"; buf1  <= "P"; buf2  <= "S"; buf3  <= "=";
            buf4  <= "0"; buf5  <= "0"; buf6  <= " "; buf7  <= "T";
            buf8  <= "H"; buf9  <= "="; buf10 <= "0"; buf11 <= "0";
            buf12 <= "0"; buf13 <= " "; buf14 <= "F"; buf15 <= "R";
            buf16 <= "="; buf17 <= "0"; buf18 <= "0"; buf19 <= "0";
            buf20 <= "0"; buf21 <= 8'h0D; buf22 <= 8'h0A;
        end else if (sec_tick) begin
            buf0  <= "F"; buf1  <= "P"; buf2  <= "S"; buf3  <= "=";
            buf4  <= {4'h0, fps_t} + "0";
            buf5  <= {4'h0, fps_u} + "0";
            buf6  <= " ";
            buf7  <= "T"; buf8  <= "H"; buf9  <= "=";
            buf10 <= {4'h0, th_h} + "0";
            buf11 <= {4'h0, th_t} + "0";
            buf12 <= {4'h0, th_u} + "0";
            buf13 <= " ";
            buf14 <= "F"; buf15 <= "R"; buf16 <= "=";
            buf17 <= {4'h0, fd3} + "0";
            buf18 <= {4'h0, fd2} + "0";
            buf19 <= {4'h0, fd1} + "0";
            buf20 <= {4'h0, fd0} + "0";
            buf21 <= 8'h0D; buf22 <= 8'h0A;
        end
        led_frame <= sec_tick ? ~led_frame : led_frame;
    end

    //------------------------------------------------- 逐字节发送
    reg [4:0] tx_idx;
    reg       tx_start;
    wire      tx_busy;

    reg [7:0] tx_byte;
    always @(*) begin
        case (tx_idx)
        5'd0:  tx_byte = buf0;   5'd1:  tx_byte = buf1;   5'd2:  tx_byte = buf2;
        5'd3:  tx_byte = buf3;   5'd4:  tx_byte = buf4;   5'd5:  tx_byte = buf5;
        5'd6:  tx_byte = buf6;   5'd7:  tx_byte = buf7;   5'd8:  tx_byte = buf8;
        5'd9:  tx_byte = buf9;   5'd10: tx_byte = buf10;  5'd11: tx_byte = buf11;
        5'd12: tx_byte = buf12;  5'd13: tx_byte = buf13;  5'd14: tx_byte = buf14;
        5'd15: tx_byte = buf15;  5'd16: tx_byte = buf16;  5'd17: tx_byte = buf17;
        5'd18: tx_byte = buf18;  5'd19: tx_byte = buf19;  5'd20: tx_byte = buf20;
        5'd21: tx_byte = buf21;  5'd22: tx_byte = buf22;
        default: tx_byte = 8'h00;
        endcase
    end

    reg       sending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sending  <= 1'b0;
            tx_idx   <= 5'd0;
            tx_start <= 1'b0;
        end else begin
            tx_start <= 1'b0;

            if (sec_tick)
                sending <= 1'b1;

            if (sending) begin
                if (!tx_busy && !tx_start) begin
                    tx_start <= 1'b1;
                    if (tx_idx == 5'd22) begin
                        tx_idx  <= 5'd0;
                        sending <= 1'b0;
                    end else begin
                        tx_idx <= tx_idx + 5'd1;
                    end
                end
            end
        end
    end

    uart_tx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (115200)
    ) u_uart (
        .clk      (clk),
        .rst_n    (rst_n),
        .din      (tx_byte),
        .din_valid(tx_start),
        .tx       (uart_tx),
        .busy     (tx_busy)
    );

endmodule

`default_nettype wire
