`timescale 1ns / 1ps

module uart_tx #(
    parameter FRAME_BITS = 8,   // Number of data bits (7 or 8 typically)
    PARITY_BIT = 2,             // Default: Parity disabled
    STOP_BITS = 1,              // Default: One stop bit
    RETENTION_DURATION = 15     // Compensation factor for UART clock oversampling
)(
    input clk,
    input tx_enable,
    input [FRAME_BITS-1:0] data,
    output reg tx,
    output reg tx_busy
);

// Calculate the total number of bits to transmit, including start, parity, and stop bits
localparam N_TX_BITS = (PARITY_BIT < 2) ? 
                        (1 + FRAME_BITS + 1 + STOP_BITS) : (1 + FRAME_BITS + STOP_BITS);
localparam INDEX_SIZE = $clog2(N_TX_BITS);

// FSM states
localparam IDLE = 0;        // Waiting for tx_enable assertion
localparam CAPTURE = 1;     // Capturing input data and preparing frame
localparam TRANSMITTING = 2;// Actively transmitting data

// Internal registers
reg [2:0] state;               // FSM state tracking
reg data_framed;               // Flag indicating data is stored for transmission
reg [INDEX_SIZE:0] bit_index;  // Tracks current transmission bit index
reg [0:N_TX_BITS-1] local_data;// Local register storing the full transmission frame

// Retention counter to maintain TX signal for necessary duration
reg [$clog2(RETENTION_DURATION):0] retention_counter;

// Initialization of registers
initial begin
    tx = 1;                     // Default TX state is high (idle state in UART)
    tx_busy = 0;                 // TX is initially idle
    state = IDLE;
    bit_index = 0;
    data_framed = 0;
    local_data = 0;
    retention_counter = RETENTION_DURATION; // Preload retention counter
end

// FSM State Transitions
always @(posedge clk) begin
    case(state)
        IDLE:
            state <= (tx_enable) ? CAPTURE : IDLE; // Move to CAPTURE state on tx_enable assertion
        
        CAPTURE:
            state <= (data_framed) ? TRANSMITTING : CAPTURE; // Transition when data is ready
            
        TRANSMITTING:
            state <= (bit_index == N_TX_BITS) ? IDLE : TRANSMITTING; // End transmission when all bits are sent
    endcase 
end

// FSM Functional Behavior
always @(posedge clk) begin
    case(state)
        IDLE: begin
                tx <= 1; // Ensure TX line is idle (high) when not transmitting
                tx_busy <= 0;
                bit_index <= 0;
                local_data <= 0;
                data_framed <= 0;
                retention_counter <= RETENTION_DURATION;
            end
            
        CAPTURE: begin
            tx_busy <= 1; // TX is now busy
            
            // Prepare the transmission frame (reverse data for correct transmission order)
            if (PARITY_BIT < 2) begin
                local_data <= {
                    1'b0,       // Start bit
                    data[0],    // Reversed data bits (LSB first)
                    data[1],
                    data[2],
                    data[3],
                    data[4],
                    data[5],
                    data[6],
                    data[7],
                    ^data,      // Parity bit
                    {(STOP_BITS){1'b1}} // Stop bit(s)
                };
                data_framed <= 1;
            end else begin
                // Same as above, but without parity
                local_data <= {
                    1'b0,       // Start bit
                    data[0],
                    data[1],
                    data[2],
                    data[3],
                    data[4],
                    data[5],
                    data[6],
                    data[7],
                    {(STOP_BITS){1'b1}} // Stop bit(s)
                };
                data_framed <= 1;
            end
        end
        
        TRANSMITTING: begin
            if (retention_counter == 0) begin
                tx <= local_data[bit_index]; // Send current bit
                bit_index <= bit_index + 1; // Move to next bit
                
                if (bit_index == N_TX_BITS)
                    tx_busy <= 0; // Transmission complete
            end
            
            // Manage retention counter to maintain TX bit duration
            if (retention_counter < RETENTION_DURATION)
                retention_counter <= retention_counter + 1;
            else
                retention_counter <= 0;
        end
    endcase
end

endmodule

