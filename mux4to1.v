`timescale 1ns / 1ps

// ====================== 4-to-1 MUX ===========================
(* dont_touch = "yes", keep_hierarchy = "yes" *)
module mux4to1(
    input in0, in1, in2, in3,
    input [1:0] sel,
    output reg out_mux
);
    always @(*) begin
        case (sel)
            2'b00: out_mux = in0;
            2'b01: out_mux = in1;
            2'b10: out_mux = in2;
            2'b11: out_mux = in3;
            default: out_mux = 1'b0;
        endcase
    end
endmodule