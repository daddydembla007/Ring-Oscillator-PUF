`timescale 1ns / 1ps
// ====================== Comparator Module ===========================
module comparator(
    input [29:0] a,
    input [29:0] b,
    output result
);
    assign result = (a > b) ? 1'b1 : 1'b0;
endmodule