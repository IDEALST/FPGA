//=============================================================================
// 文件    : frame_stat.v
// 功能    : 帧率统计
//           1) 用 frame_start 计帧；
//           2) 用 1 秒闸门测量帧率（0~255）；
//           3) 输出 4 位 BCD 帧计数（便于串口直接打印，无需除法）。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module frame_stat #(
    parameter integer CLK_HZ = 74166667
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       frame_start,
    output reg  [7:0] fps,           // 每秒更新一次
    output reg  [3:0] fd3, fd2, fd1, fd0,   // BCD 帧计数
    output reg        sec_tick       // 1 秒脉冲，1 拍宽
);

    localparam [31:0] ONE_SEC = CLK_HZ;

    reg [31:0] cnt_1s;
    reg [7:0]  cnt_frm;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt_1s   <= 32'd0;
            cnt_frm  <= 8'd0;
            fps      <= 8'd0;
            sec_tick <= 1'b0;
        end else begin
            sec_tick <= 1'b0;

            if (cnt_1s >= ONE_SEC - 32'd1) begin
                cnt_1s   <= 32'd0;
                fps      <= cnt_frm;
                cnt_frm  <= 8'd0;
                sec_tick <= 1'b1;
            end else begin
                cnt_1s <= cnt_1s + 32'd1;
                if (frame_start)
                    cnt_frm <= cnt_frm + 8'd1;
            end
        end
    end

    //------------------------------------------------- BCD 帧计数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fd3 <= 4'd0; fd2 <= 4'd0; fd1 <= 4'd0; fd0 <= 4'd0;
        end else if (frame_start) begin
            if (fd0 != 4'd9) begin
                fd0 <= fd0 + 4'd1;
            end else begin
                fd0 <= 4'd0;
                if (fd1 != 4'd9) begin
                    fd1 <= fd1 + 4'd1;
                end else begin
                    fd1 <= 4'd0;
                    if (fd2 != 4'd9) begin
                        fd2 <= fd2 + 4'd1;
                    end else begin
                        fd2 <= 4'd0;
                        if (fd3 != 4'd9) fd3 <= fd3 + 4'd1;
                        else             fd3 <= 4'd0;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
