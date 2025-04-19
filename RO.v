`timescale 1ns / 1ps
module RO(
    input clk,
    input rst,
    input in_valid,
    input [3:0] challange,
    output reg response_bit  
);

    (* dont_touch = "yes" *) wire[7:0] ro_out;
    (* dont_touch = "yes" *) wire mux_out1;
    (* dont_touch = "yes" *) wire mux_out2;

    (* dont_touch = "yes" *) reg [15:0] on_counter = 0;
    (* dont_touch = "yes" *) wire n_in_valid = &on_counter;

    (* dont_touch = "yes" *) reg [29:0] cnt1 = 0;
    (* dont_touch = "yes" *) reg [29:0] cnt2 = 0;

    (* dont_touch = "yes" *) reg mux1_d = 0, mux2_d = 0;
    wire rising_edge1 = ~mux1_d & mux_out1;
    wire rising_edge2 = ~mux2_d & mux_out2;

    wire comp_result;

    // Instantiate ROs
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro1 (.enable(n_in_valid), .out(ro_out[0]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro2 (.enable(n_in_valid), .out(ro_out[1]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro3 (.enable(n_in_valid), .out(ro_out[2]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro4 (.enable(n_in_valid), .out(ro_out[3]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro5 (.enable(n_in_valid), .out(ro_out[4]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro6 (.enable(n_in_valid), .out(ro_out[5]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro7 (.enable(n_in_valid), .out(ro_out[6]));
    (* dont_touch = "yes", keep_hierarchy = "yes" *) ring_osci ro8 (.enable(n_in_valid), .out(ro_out[7]));

    // MUXes
    (* dont_touch = "yes", keep_hierarchy = "yes" *) mux4to1 mux1(ro_out[0],ro_out[1],ro_out[2],ro_out[3],challange[1:0],mux_out1);
    (* dont_touch = "yes", keep_hierarchy = "yes" *) mux4to1 mux2(ro_out[4],ro_out[5],ro_out[6],ro_out[7],challange[3:2],mux_out2);

    // Comparator
    comparator comp_inst(.a(cnt1), .b(cnt2), .result(comp_result));

    // Enable RO after delay
    always @(posedge clk or posedge rst) begin
        if (rst)
            on_counter <= 0;
        else if (!n_in_valid && in_valid)
            on_counter <= on_counter + 1;
    end

    // Edge counting logic with sync
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mux1_d <= 0;
            cnt1 <= 0;
        end else begin
            mux1_d <= mux_out1;
            if (n_in_valid && rising_edge1 && cnt1 != 30'h3FFFFFFF)
                cnt1 <= cnt1 + 1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mux2_d <= 0;
            cnt2 <= 0;
        end else begin
            mux2_d <= mux_out2;
            if (n_in_valid && rising_edge2 && cnt2 != 30'h3FFFFFFF)
                cnt2 <= cnt2 + 1;
        end
    end

    // Result logic using comparator
    always @(posedge clk or posedge rst) begin
        if (rst)
            response_bit <= 1'b1;  // can be default 0 if preferred
        else if (cnt1 == 30'd10000000)
            response_bit <= comp_result;
    end

endmodule
