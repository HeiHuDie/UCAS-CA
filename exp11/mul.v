module Mul(
    input mul_clk,
    input reset,
    input mul,
    input mul_signed,
    input [31:0] x,
    input [31:0] y,
    output [63:0] result,
    output mul_complete
    );
    reg  [1:0]  cnt;
    always @(posedge mul_clk) begin
        if (reset) begin
            cnt <= 2'b0;
        end
        else if (mul) begin
            if (mul_complete) begin
                cnt <= 2'b0;
            end
            else begin 
                cnt <= cnt + 1;
            end
        end
    end
    assign mul_complete = cnt == 2'b01;

    wire [32:0] ex_x;
    wire [32:0] ex_y;

    assign ex_x = { {x[31] & mul_signed}, x};
    assign ex_y = { {y[31] & mul_signed}, y};

    wire [65:0] p [16:0];
    wire [16:0] c;
    wire [65:0] zero;
    assign zero = 66'b0;
    
    genvar i;
    generate
        for (i = 0; i < 33; i = i + 2)
        begin:b
            if (i == 0) begin
                booth u_booth (
                    .y2 (ex_y[i + 1]),
                    .y1 (ex_y[i]),
                    .y0 (0),
                    .X  ({{(33){ex_x[32]}}, ex_x}),
                    .p  (p[i / 2]),
                    .c  (c[i / 2])
                );
            end
            else if (i == 32) begin
                booth u_booth (
                    .y2 (ex_y[i]),
                    .y1 (ex_y[i]),
                    .y0 (ex_y[i - 1]),
                    .X  ({{(33 - i){ex_x[32]}}, ex_x, zero[(i - 1):0]}),
                    .p  (p[i / 2]),
                    .c  (c[i / 2])
                );
            end
            else begin
                booth u_booth (
                    .y2 (ex_y[i + 1]),
                    .y1 (ex_y[i]),
                    .y0 (ex_y[i - 1]),
                    .X  ({{(33 - i){ex_x[32]}}, ex_x, zero[(i - 1):0]}),
                    .p  (p[i / 2]),
                    .c  (c[i / 2])
                );
            end
        end
    endgenerate

    wire [16:0] pt [65:0];

    generate
        for (i = 0; i < 66; i = i + 1)
            begin
                assign pt[i] = {p[16][i], p[15][i], p[14][i], p[13][i], p[12][i], p[11][i], p[10][i], p[9][i], p[8][i], p[7][i], p[6][i], p[5][i], p[4][i], p[3][i], p[2][i], p[1][i], p[0][i]};
            end 
    endgenerate

    wire [13:0] wcout [65:0];
    wire [65:0] A;
    wire [66:0] B;

    generate
        for (i = 0; i < 66; i = i + 1)
        begin:w
            if (i == 0) begin
                Wallace u_Wallace (
                    .mul_clk (mul_clk),
                    .reset   (reset),
                    .mul     (mul),
                    .num     (pt[i]),
                    .cin     (c[13:0]),
                    .cout    (wcout[i]),
                    .S       (A[i]),
                    .C       (B[i + 1])
                ); 
            end
            else begin
                Wallace u_Wallace (
                    .mul_clk (mul_clk),
                    .reset   (reset),
                    .mul     (mul),
                    .num     (pt[i]),
                    .cin     (wcout[i - 1]),
                    .cout    (wcout[i]),
                    .S       (A[i]),
                    .C       (B[i + 1])
                ); 
            end
        end
    endgenerate

    wire [65:0] product;
    assign product = A + {B[66:1], c[14]} + c[15];

    assign result = product[63:0];

endmodule
