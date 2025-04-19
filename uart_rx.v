`timescale 1ns / 1ps
module uart_rx #(
    parameter FRAME_BITS = 8, // Number of data bits, can be 7/8
    PARITY_BIT = 2, // Parity disabled by default
    STOP_BITS = 1   // Using only 1 stop bit
) (
    input rx,
    input i_clk,
    input flush,
    output reg [FRAME_BITS-1:0] data,
    output reg converted,
    output reg data_valid,
    output reg busy
);

// FSM states
localparam IDLE         = 0;
localparam DETECT_START = 1;
localparam STARTED      = 2;
localparam CONVERSION   = 3;

// Calculating the total number of bits that need to be stored
localparam TOTAL_RX_BITS = (PARITY_BIT < 2 ) ? FRAME_BITS + STOP_BITS + 1 : FRAME_BITS + STOP_BITS;

// Hardcoding the number of samples per bit.
// Change this according to the input clock frequency
localparam OVERSAMPLE_FACTOR = 15;

// Three parameters used by the "obtained_bit" function
localparam integer SAMPLE_LOC_1 = (OVERSAMPLE_FACTOR / 2) - 1;
localparam integer SAMPLE_LOC_2  = (OVERSAMPLE_FACTOR / 2);
localparam integer SAMPLE_LOC_3 = (OVERSAMPLE_FACTOR / 2) + 1;

reg [1:0] state;            // FSM state

reg [3:0] bit_location;     // Indexing variable for the received data
reg [3:0] insert_location;  //  current index of data in oversampling buffer

reg [OVERSAMPLE_FACTOR-1:0] oversampled_bit;    // oversampling buffer
reg [TOTAL_RX_BITS-1:0] sampled_rx_data;        // RX buffer

initial begin
    
    `ifdef DEBUG
        $display("Oversampling factor: %2d", OVERSAMPLE_FACTOR);
    `endif

    state = IDLE;

    busy = 0;
    bit_location = 0;
    insert_location = 0;
    sampled_rx_data = {(TOTAL_RX_BITS-1){1'b0}};
end

// Managing the states of the conversion FSM
always @(posedge i_clk) begin
    case (state)

        // Unless "0" is detected on RX line, wait
        IDLE :
            state <= rx ? IDLE : DETECT_START;
            
        // Once "0" is seen on RX line, sample certain times, decide if RX started
        // If RX started, go to next state
        DETECT_START: begin
            if(insert_location == (OVERSAMPLE_FACTOR-4))
                if(busy)
                    state <= STARTED;
                else begin
                    state <= IDLE;
                end
            end

        // Receive all bits of the RX data, with oversampling
        STARTED:
            state <= (bit_location == TOTAL_RX_BITS) ? CONVERSION : STARTED;

        // Check parity, then retain data until data is flushed
        CONVERSION: 
            state <= (flush) ? IDLE : CONVERSION;        
    endcase
end

// Actual logic in each state
always @(posedge i_clk) begin
    case (state)
    
        // Simply reset all the vectors
        IDLE: begin
            converted <= 0;
            data_valid <= 0;
            busy <= 0;
            bit_location <= 0;
            insert_location <= 0; // Not really needed
            oversampled_bit <= 15'b0;
            sampled_rx_data = {(TOTAL_RX_BITS-1){1'b0}};
            data <= {FRAME_BITS{1'b0}};
        end
        
        // Try to detect if a zero bit is detected, marking start of transmission
        DETECT_START: begin
            if (insert_location == (OVERSAMPLE_FACTOR - 5)) begin
                busy <= ~obtained_bit(oversampled_bit);    // Decide what bit was received
                oversampled_bit <= 15'b0;   // Reset the oversampling buffer
            end
            else
                oversampled_bit[insert_location] <= rx; // Fill the oversample buffer

            if(busy)
                insert_location <= 0; // Increment insertion location
            else
                insert_location <= insert_location + 1;
        end
        
        // Once transmission start is confirmed, start receiving the data, with oversampling
        STARTED: begin
            oversampled_bit[insert_location] <= rx;
            insert_location <= insert_location + 1;

            // Once oversampling buffer is full, decide what bit was received
            if (insert_location == OVERSAMPLE_FACTOR - 1) begin
                sampled_rx_data[bit_location] <= obtained_bit(oversampled_bit);
                oversampled_bit <= 15'b0;   // Reset the oversampling buffer
                
                bit_location <= bit_location + 1;
            end
        end
        
        // Transmission complete, check parity, put out data and other flag bits
        CONVERSION: begin
            if(~converted) begin
                converted <= 1;
                data <= sampled_rx_data[FRAME_BITS-1:0];
    
                if(PARITY_BIT < 2) begin
                    if (^data == PARITY_BIT)
                        data_valid <= 1;
                    else
                        data_valid <= 0;
                end
                else
                    data_valid <= 1;
            end
        end
    endcase
end

// Function to decide the received bit, depending on the oversampled data bits
function obtained_bit (input [OVERSAMPLE_FACTOR-1:0] oversampled_vector);
    obtained_bit =  (oversampled_vector[SAMPLE_LOC_1] & oversampled_vector[SAMPLE_LOC_2]) | 
                    (oversampled_vector[SAMPLE_LOC_2] & oversampled_vector[SAMPLE_LOC_3]) | 
                    (oversampled_vector[SAMPLE_LOC_1] & oversampled_vector[SAMPLE_LOC_3]);
endfunction
    
endmodule