`timescale 1ns / 1ps
// ====================== Ring Oscillator ===========================
(* dont_touch = "yes", keep_hierarchy = "yes" *)
module ring_osci(
    input enable,
    output out
);
    (* dont_touch = "yes" *) wire w1, w2, w3, w4, w5, w6, w7, w8, feedback;

    assign w1 = (enable & feedback);
    assign w2 = ~w1;
    assign w3 = ~w2;
    assign w4 = ~w3;
    assign w5 = ~w4;
    assign w6 = ~w5;
    assign w7 = ~w6;
    assign w8 = ~w7;
    assign feedback = w8;
    assign out = ~w8;

endmodule