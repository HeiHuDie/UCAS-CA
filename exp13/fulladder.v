module fulladder(
    input A,
    input B,
    input cin,
    output S,
    output cout
    );
    assign {cout, S} = A + B + cin;
endmodule
