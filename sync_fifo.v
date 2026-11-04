//=============================================================================
// 文件    : sync_fifo.v
// 功能    : 单时钟 FIFO（带整帧清零），用于流水线输出与 HDMI 时序之间的
//           像素对齐，吸收摄像头与显示之间的微小速率差。
//=============================================================================
`timescale 1ns / 1ps
`default_nettype none

module sync_fifo #(
    parameter integer DW = 1,
    parameter integer AW = 12
)(
    input  wire          clk,
    input  wire          rst_n,
    input  wire          flush,      // 单周期，清空 FIFO（帧起始对齐用）
    input  wire          winc,
    input  wire [DW-1:0] wdata,
    output wire          wfull,
    input  wire          rinc,
    output wire [DW-1:0] rdata,
    output wire          rempty
);

    localparam integer DEPTH    = (1 << AW);
    localparam [AW:0]  DEPTH_AW = (1 << AW);

    reg [DW-1:0] mem [0:DEPTH-1];
    reg [AW:0]   wptr, rptr;
    reg [AW:0]   cnt;

    assign wfull  = (cnt == DEPTH_AW);
    assign rempty = (cnt == {(AW+1){1'b0}});

    wire wr_en = winc & ~wfull;
    wire rd_en = rinc & ~rempty;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= {(AW+1){1'b0}};
            rptr <= {(AW+1){1'b0}};
            cnt  <= {(AW+1){1'b0}};
        end else if (flush) begin
            wptr <= {(AW+1){1'b0}};
            rptr <= {(AW+1){1'b0}};
            cnt  <= {(AW+1){1'b0}};
        end else begin
            if (wr_en) begin
                mem[wptr[AW-1:0]] <= wdata;
                wptr <= wptr + 1'b1;
            end
            if (rd_en) begin
                rptr <= rptr + 1'b1;
            end
            case ({wr_en, rd_en})
                2'b10:   cnt <= cnt + 1'b1;
                2'b01:   cnt <= cnt - 1'b1;
                default: cnt <= cnt;
            endcase
        end
    end

    assign rdata = mem[rptr[AW-1:0]];

endmodule

`default_nettype wire
