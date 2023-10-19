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
    assign mul_complete = cnt == 2'b10;

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

    reg [16:0] pt_reg [65:0];
    reg [16:0] c_reg;
    integer j;
    always @(posedge mul_clk) begin
        for (j = 0; j < 66; j = j + 1)
        begin
            if (reset) begin
                pt_reg[j] <= 17'b0;
            end
            else if (mul) begin
                pt_reg[j] <= pt[j];
            end
        end
        if (reset) begin
            c_reg <= 17'b0;
        end
        else if (mul) begin
            c_reg <= c;
        end
    end

    wire [16:0] pt_wire [65:0];
    wire [16:0] c_wire;

    assign c_wire = c_reg;

    generate
        for (i = 0; i < 66; i = i + 1)
        begin
            assign pt_wire[i] = pt_reg[i];
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
                    .num    (pt_wire[i]),
                    .cin    (c_wire[13:0]),
                    .cout   (wcout[i]),
                    .S      (A[i]),
                    .C      (B[i + 1])
                ); 
            end
            else begin
                Wallace u_Wallace (
                    .num    (pt_wire[i]),
                    .cin    (wcout[i - 1]),
                    .cout   (wcout[i]),
                    .S      (A[i]),
                    .C      (B[i + 1])
                ); 
            end
        end
    endgenerate

    wire [65:0] product;
    assign product = A + {B[66:1], c_wire[14]} + c_wire[15];

    reg [65:0] product_reg;
    always @(posedge mul_clk) begin
        if (reset) begin
            product_reg <= 66'b0;
        end
        else if (mul) begin
            product_reg <= product;
        end
    end

    assign result = product_reg[63:0];

endmodule
