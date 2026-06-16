module axis_wrapper #(
    // The FIR filter has a latency of 7 cycles
    parameter LATENCY = 7 
)(
    input wire clk,
    input wire rst_n,
    
    // AXI-Stream Slave (DMA -> FIR)
    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    
    // AXI-Stream Master (FIR -> DMA)
    output wire [15:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // 1. Connection wires to the Engine
    wire signed [15:0] filter_out;

    // 2. Engine Instantiation
    fir_filter my_engine (
        .clk(clk),
        .rst_n(rst_n),
        .audio_in(s_axis_tdata),
        .valid_in(s_axis_tvalid && s_axis_tready),
        .audio_out(filter_out)
    );

    // Always accept data from the DMA
    assign s_axis_tready = 1'b1; 

    // 3. The Control Signal Shift Registers
    // These arrays hold the control signals while the math processes
    reg [LATENCY-1:0] valid_shift;
    reg [LATENCY-1:0] last_shift;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_shift <= 0;
            last_shift  <= 0;
        end else begin
            valid_shift <= {valid_shift[LATENCY-2:0], s_axis_tvalid};
            last_shift  <= {last_shift[LATENCY-2:0], s_axis_tlast};
        end
    end

    // 4. Output Assignments
    assign m_axis_tdata  = filter_out;
    assign m_axis_tvalid = valid_shift[LATENCY-1];
    assign m_axis_tlast  = last_shift[LATENCY-1];

endmodule