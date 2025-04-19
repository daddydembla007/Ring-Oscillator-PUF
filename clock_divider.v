`timescale 1ns / 1ps
module clock_divider (
    input wire clk,          // 100 MHz input clock from Basys 3
    input wire reset,        // Active-high reset
    output reg slow_clk      // Output: low-frequency clock
);

    reg [24:0] counter;      // 26-bit counter for dividing

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            slow_clk <= 0;
        end else begin
            if (counter == 25'b1111111111111111111111111) begin
                counter <= 0;
                slow_clk <= ~slow_clk;  // Toggle output clock
            end else begin
                counter <= counter + 25'd1;
            end
        end
    end

endmodule

