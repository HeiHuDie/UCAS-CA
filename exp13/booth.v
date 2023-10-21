module booth(
    input y2,
    input y1,
    input y0,
    input [65:0] X,
    output [65:0] p,
    output c
    );
    wire addx; 
    wire add2x;
    wire subx; 
    wire sub2x;
    assign addx = ~y2&y1&~y0 | ~y2&~y1&y0;
    assign add2x = ~y2&y1&y0;
    assign subx = y2&y1&~y0 | y2&~y1&y0;
    assign sub2x = y2&~y1&~y0;
    assign c = sub2x | subx;
    assign p[0] = subx&~X[0] | addx&X[0] | sub2x;
    genvar i;
    generate
        for (i = 1; i < 66; i = i + 1) 
            begin:useless
                assign p[i] = subx&~X[i] | sub2x&~X[i - 1] | addx&X[i] | add2x&X[i - 1];
            end
    endgenerate
endmodule
