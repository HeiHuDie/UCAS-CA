module Wallace(
    input mul_clk,
    input reset,
    input mul,
    input [16:0] num,
    input [13:0] cin,
    output [13:0] cout,
    output S,
    output C
    );
    wire [4:0] in2;
    fulladder adder11 (
        .A      (num[0]),
        .B      (num[1]),
        .cin    (num[2]),
        .S      (in2[0]),
        .cout   (cout[0])
    );
    fulladder adder12 (
        .A      (num[3]),
        .B      (num[4]),
        .cin    (num[5]),
        .S      (in2[1]),
        .cout   (cout[1])
    );
    fulladder adder13 (
        .A      (num[6]),
        .B      (num[7]),
        .cin    (num[8]),
        .S      (in2[2]),
        .cout   (cout[2])
    );
    fulladder adder14 (
        .A      (num[9]),
        .B      (num[10]),
        .cin    (num[11]),
        .S      (in2[3]),
        .cout   (cout[3])
    );
    fulladder adder15 (
        .A      (num[12]),
        .B      (num[13]),
        .cin    (num[14]),
        .S      (in2[4]),
        .cout   (cout[4])
    );
    
    wire [3:0] in3;
    fulladder adder21 (
        .A      (num[15]),
        .B      (num[16]),
        .cin    (in2[0]),
        .S      (in3[0]),
        .cout   (cout[5])
    );
    fulladder adder22 (
        .A      (in2[1]),
        .B      (in2[2]),
        .cin    (in2[3]),
        .S      (in3[1]),
        .cout   (cout[6])
    );
    fulladder adder23 (
        .A      (in2[4]),
        .B      (cin[0]),
        .cin    (cin[1]),
        .S      (in3[2]),
        .cout   (cout_wire[0])
    );
    fulladder adder24 (
        .A      (cin[2]),
        .B      (cin[3]),
        .cin    (cin[4]),
        .S      (in3[3]),
        .cout   (cout_wire[1])
    );

    wire [1:0] in4_wire;

    fulladder adder31 (
        .A      (in3[0]),
        .B      (in3[1]),
        .cin    (in3[2]),
        .S      (in4_wire[0]),
        .cout   (cout_wire[2])
    );
    fulladder adder32 (
        .A      (in3[3]),
        .B      (cin[5]),
        .cin    (cin[6]),
        .S      (in4_wire[1]),
        .cout   (cout_wire[3])
    );
    
    wire [3:0] cout_wire;
    wire [1:0] in4;
    reg  [1:0] in4_reg;
    reg  [3:0] cout_reg;

    always @(posedge mul_clk) begin
        if (reset) begin
            in4_reg <= 2'b0;
            cout_reg <= 4'b0;
        end
        else if (mul) begin
            in4_reg <= in4_wire;
            cout_reg <= {cout_wire[3], cout_wire[2], cout_wire[1], cout_wire[0]};
        end
    end
    assign {cout[10], cout[9], cout[8], cout[7]} = cout_reg;
    assign in4 = in4_reg;

    wire [1:0] in5;
    fulladder adder41 (
        .A      (in4[0]),
        .B      (in4[1]),
        .cin    (cin[7]),
        .S      (in5[0]),
        .cout   (cout[11])
    );
    fulladder adder42 (
        .A      (cin[8]),
        .B      (cin[9]),
        .cin    (cin[10]),
        .S      (in5[1]),
        .cout   (cout[12])
    );

    wire    in6;
    fulladder adder51 (
        .A      (in5[0]),
        .B      (in5[1]),
        .cin    (cin[11]),
        .S      (in6),
        .cout   (cout[13])
    );

    fulladder adder61 (
        .A      (in6),
        .B      (cin[12]),
        .cin    (cin[13]),
        .S      (S),
        .cout   (C)
    );


endmodule
