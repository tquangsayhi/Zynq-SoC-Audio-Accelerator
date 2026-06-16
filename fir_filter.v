module fir_filter (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] audio_in,
    input wire valid_in,
    output wire signed [15:0] audio_out
);
    // 1. The Shift Register
    reg signed [15:0] shift_reg [0:31];
    // 2. The Coefficients from python
    reg signed [15:0] COEFF [0:31];

    initial begin
        COEFF[0]  = 16'd151;
        COEFF[1]  = 16'd169;
        COEFF[2]  = 16'd223;
        COEFF[3]  = 16'd310;
        COEFF[4]  = 16'd428;
        COEFF[5]  = 16'd571;
        COEFF[6]  = 16'd735;
        COEFF[7]  = 16'd911;
        COEFF[8]  = 16'd1094;
        COEFF[9]  = 16'd1276;
        COEFF[10] = 16'd1449;
        COEFF[11] = 16'd1606;
        COEFF[12] = 16'd1740;
        COEFF[13] = 16'd1846;
        COEFF[14] = 16'd1919;
        COEFF[15] = 16'd1956;
        COEFF[16] = 16'd1956;
        COEFF[17] = 16'd1919;
        COEFF[18] = 16'd1846;
        COEFF[19] = 16'd1740;
        COEFF[20] = 16'd1606;
        COEFF[21] = 16'd1449;
        COEFF[22] = 16'd1276;
        COEFF[23] = 16'd1094;
        COEFF[24] = 16'd911;
        COEFF[25] = 16'd735;
        COEFF[26] = 16'd571;
        COEFF[27] = 16'd428;
        COEFF[28] = 16'd310;
        COEFF[29] = 16'd223;
        COEFF[30] = 16'd169;
        COEFF[31] = 16'd151;
    end
    // 3. The multiplication register at each position
    reg signed [31:0] mul [0:31];

    // 4. The addition layers (32 coefficients => 5 layers of addition)
    reg signed [32:0] add_layer1 [0:15]; // 16 sums
    reg signed [33:0] add_layer2 [0:7];  // 8 sums
    reg signed [34:0] add_layer3 [0:3];  // 4 sums
    reg signed [35:0] add_layer4 [0:1];  // 2 sums
    reg signed [36:0] add_layer5;        // Final sum

    integer i, j;
   always @(posedge clk) begin
        if (rst_n == 1'b0) begin
            for (i = 0; i < 32; i = i + 1) shift_reg[i] <= 16'd0;
        end else if (valid_in) begin 
            shift_reg[0] <= audio_in;
            for (i = 31; i > 0; i = i - 1) begin
                shift_reg[i] <= shift_reg[i-1];
            end
        end
    end

    always @(posedge clk) begin
        for (j = 0; j < 32; j = j + 1) begin
            mul[j] <= shift_reg[j] * COEFF[j];
        end
    end

    // 1st layer of addition
    always @(posedge clk) begin
        for (i = 0; i < 16; i = i + 1) begin
            add_layer1[i] <= mul[2*i] + mul[2*i + 1];
        end
    end
    // 2nd layer of addition
    always @(posedge clk) begin
        for (i = 0; i < 8; i = i + 1) begin
            add_layer2[i] <= add_layer1[2*i] + add_layer1[2*i + 1];
        end
    end
    // 3rd layer of addition
    always @(posedge clk) begin
        for (i = 0; i < 4; i = i + 1) begin
            add_layer3[i] <= add_layer2[2*i] + add_layer2[2*i + 1];
        end
    end
    // 4th layer of addition
    always @(posedge clk) begin
        for (i = 0; i < 2; i = i + 1) begin
            add_layer4[i] <= add_layer3[2*i] + add_layer3[2*i + 1];
        end
    end
    // 5th layer of addition (final output)
    always @(posedge clk) begin
        add_layer5 <= add_layer4[0] + add_layer4[1];
    end

    assign audio_out = add_layer5[30:15]; // Take the upper 16 bits as output
endmodule