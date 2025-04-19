`timescale 1ns / 1ps
module controller(
//    input n_in_invalid,
    input clk_100MHz,  // System clock
    input rx,          // UART receive input
    output tx,         // UART transmit output
    output rx_busy,    // UART RX busy flag
    output converted,  // UART RX data converted flag
    output data_valid, // UART RX data valid flag
    output tx_busy,     // UART TX busy flag
    input rst,
    input en,
    output wire [1:0] out_bit,    // Output from RO module
    output wire [3:0] challenge_out,  // Added: challenge output
//    output reg start_tx,
    output wire start_tx,
    input [3:0]seed
    
);
    
    // FSM states
    localparam LFSR=6;
    localparam RX_NUM_1_LB = 0; // Receive lower byte of first number
    localparam RX_NUM_1_HB = 1; // Receive higher byte of first number
    localparam RX_NUM_2_LB = 2; // Receive lower byte of second number
    localparam RX_NUM_2_HB = 3; // Receive higher byte of second number
    localparam TX_NUM_1 = 4;    // Transmit higher byte of sum
    localparam TX_NUM_2 = 5;    // Transmit lower byte of sum
    reg [2:0] state; // FSM state register
    reg allow_next;  // Control flag for state transition
    reg flush_ctrl;  // Control flag for UART RX flush
    reg tx_enable_ctrl; // Control flag for UART TX enable
    wire [7:0] uart_data; // UART received data
    reg [7:0] out_data;   // Data to be transmitted
    reg [7:0] byte_buffer; // Temporary storage for received byte
    reg [15:0] sum;       // Sum of received numbers
    
    // UART clock generation variables
    reg clk_uart;   // UART clock signal
    reg [26:0] counter; // Clock divider counter
    wire [0:15]seq;// now its reg previously when i was checking uart it was reg now we are connecting to a output so it wire not reg
    reg [7:0]count_lfsr_clk;//clock divider for lfsr
    // UART RX instance
    uart_rx uart_rx_115200 (
        .rx(rx),
        .i_clk(clk_uart),
        .flush(flush_ctrl),
        .data(uart_data),
        .converted(converted),
        .data_valid(data_valid),
        .busy(rx_busy)
    );
    
    // UART TX instance
    uart_tx uart_tx_115200(
        .clk(clk_uart),
        .tx_enable(tx_enable_ctrl),
        .data(out_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );
//    RO RO_OP(.lfsr_clk(clk_lfsr),.seq(seq),.stop(stop),.challange(challange),.n_in_valid(n_in_valid));
    top op(.clk(clk_100MHz),.rst(rst),.en(en),.seed(seed),.start_tx(start_tx),.seq(seq),.out_bit(out_bit),.challenge_out(challenge_out));
    // Initial values for registers
    initial begin
        counter = 0;
        clk_uart = 0;
        flush_ctrl = 0;
        tx_enable_ctrl = 0;
        sum = 0;
        out_data = 0;
        byte_buffer = 0;
        state = LFSR;
        allow_next = 0;
//        seq=16'b0010_0101_0000_1111;
//        clk_lfsr=0;
    end
    
    // Generate UART clock at 115200 baud
    always @(posedge clk_100MHz) begin
        counter <= counter + 1;
        if(counter == 5'd27) begin
            counter <= 0;
            clk_uart <= ~clk_uart;
        end
    end
    
    //clock for lfsr this code block makes the frequency of lfsr as 1 MHz
//    always@(posedge clk_100MHz)
//    begin
//    count_lfsr_clk<=count_lfsr_clk+1;
//    if(count_lfsr_clk==16'd65530)
//    begin
//    count_lfsr_clk=0;
//    clk_lfsr<=~clk_lfsr;
//    end
//    end
//    always@(posedge button)
//    begin
//    clk_lfsr<=~clk_lfsr;
//    end
   
    
   
    // FSM for data reception and transmission
    always @(posedge clk_uart) begin
        case(state)
            LFSR:begin
            if (start_tx)
            begin
            state<=RX_NUM_1_HB;
            end
            else
            begin
            state<=LFSR;
            end
            end
       
            RX_NUM_1_LB: begin
                tx_enable_ctrl <= 0; // Disable TX during reception
                if(converted) begin
                    sum <= {8'b0, uart_data}; // Store received byte
                    flush_ctrl <= 1; // Flush RX buffer
                    state <= RX_NUM_1_HB;
                end
            end

            RX_NUM_1_HB: begin
                if(~flush_ctrl && ~converted)
                    allow_next <= 1; // Allow next RX cycle
                
                if(converted && ~flush_ctrl && allow_next) begin
                    sum <= {uart_data, sum[7:0]}; // Store second byte
                    flush_ctrl <= 1; // Flush RX buffer
                    allow_next <= 0;
                    state <= RX_NUM_2_LB;
                end
                else
                    flush_ctrl <= 0;
            end
            
            RX_NUM_2_LB: begin
                if(~flush_ctrl && ~converted)
                    allow_next <= 1;
                
                if(converted && ~flush_ctrl && allow_next) begin
                    byte_buffer <= uart_data; // Store lower byte of second number
                    flush_ctrl <= 1;
                    allow_next <= 0;
                    state <= RX_NUM_2_HB;
                end
                else
                    flush_ctrl <= 0;
            end
            
            RX_NUM_2_HB: begin
                if(~flush_ctrl && ~converted)
                    allow_next <= 1;
                
                if(converted && ~flush_ctrl && allow_next) begin
                    sum <= sum + {uart_data, byte_buffer}; // Compute sum
                    byte_buffer <= 0;
                    flush_ctrl <= 1;
                    allow_next <= 0;
                    state <= TX_NUM_1;
                end
                else
                    flush_ctrl <= 0;
            end

            TX_NUM_1: begin
                out_data <= seq[0:7]; // Send higher byte of sum
                if(~tx_busy && ~allow_next)
                    tx_enable_ctrl <= 1; // Start transmission
                else begin
                    allow_next <= 1;
                    flush_ctrl <= 0;
                    tx_enable_ctrl <= 0;
                end
                if(~tx_busy && allow_next) begin
                    allow_next <= 0;
                    state <= TX_NUM_2;
                end
            end
            
            TX_NUM_2: begin
                out_data <= seq[8:15]; // Send lower byte of sum
                if(~tx_busy && ~allow_next)
                    tx_enable_ctrl <= 1;
                else begin
                    allow_next <= 1;
                    tx_enable_ctrl <= 0;
                end
                if(~tx_busy && allow_next) begin
                    allow_next <= 0;
                    state <= RX_NUM_1_LB; // Reset to receive new data
                end
            end
        endcase
    end
endmodule


