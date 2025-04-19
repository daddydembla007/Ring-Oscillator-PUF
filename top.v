`timescale 1ns / 1ps

module top(
    input clk,                  // 100 MHz Basys clock
    input rst,
    input en,
    input [3:0] seed,           // Seed to initialize challenge
    output reg [1:0] out_bit,    // Output from RO module
    output wire [3:0] challenge_out,  // Added: challenge output
    output reg start_tx,
    output reg[15:0]seq
);
    reg [4:0]index;
    wire response_bit;
    wire slow_clk;
    
    initial begin
    index=0;
    seq=16'b0;
    end
    // Clock divider to generate slow clock
    clock_divider clk1 (
        .clk(clk),
        .reset(rst),
        .slow_clk(slow_clk)
    );

    // FSM state counter (0 to 3)
    reg [1:0] slow_count;
    reg internal_rst;
    reg internal_in_valid;
    reg [3:0] challenge;
    
    assign challenge_out = challenge; 

    // 4-bit LFSR logic for challenge generation
    wire [3:0] next_challenge = {challenge[2:0], challenge[3] ^ challenge[2]}; // Example lfsr

    // FSM: drives signals across 4 slow clock ticks
    always @(posedge slow_clk or posedge rst) begin
        if (rst) begin
            slow_count <= 2'b00;
            internal_rst <= 1'b1;
            internal_in_valid <= 1'b0;
            challenge <= seed;
        end else begin
            case (slow_count)
                2'd0: begin
                    internal_rst <= 1'b1;
                    internal_in_valid <= 1'b0;
                    out_bit = 2'b00;
                end
                2'd1: begin
                    internal_rst <= 1'b0;
                    challenge <= next_challenge; // LFSR advance
                end
                2'd2: begin
                    if (en)
                        internal_in_valid <= 1'b1;
                end
                2'd3: begin
                    if (en)
                        begin
                        if(start_tx==0) begin
                            if(response_bit) out_bit[1] <= 1;
                            else out_bit[0] <= 1;
                            seq[index]<=response_bit;
                            index<=index+1;
                            end
                        end
                    internal_in_valid <= 1'b0;
                end
            endcase
            if (index>=15)begin start_tx<=1;end
            slow_count <= slow_count + 2'b01;
        end
    end

    // Connect to the RO PUF module
    RO ro_inst (
        .clk(clk),
        .rst(internal_rst),
        .in_valid(internal_in_valid),
        .challange(challenge),
        .response_bit(response_bit)
    );

endmodule