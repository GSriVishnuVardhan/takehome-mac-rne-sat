`timescale 1ns/1ps
//
// mac_rne_sat -- GOLDEN reference implementation (validation only; never
// shipped to the agent or the candidate).
//
module mac_rne_sat (
    input  logic               clk,
    input  logic               rst,       // synchronous, active-high
    input  logic               en,        // accumulate a*b this cycle
    input  logic               clr,       // clear accumulator this cycle
    input  logic               rd,        // request readout snapshot this cycle
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] res,       // rounded + saturated snapshot
    output logic               res_valid, // 1-cycle pulse, one cycle after rd
    output logic               ovf        // sticky saturation flag
);

    localparam int ACC_W = 28;

    logic signed [ACC_W-1:0] acc;

    // Product of current operands (consumed only when en is high).
    wire signed [15:0] prod = a * b;
    wire signed [ACC_W-1:0] prod_x = {{(ACC_W-16){prod[15]}}, prod};

    // ---- Readout path: snapshot is the accumulator BEFORE this cycle's
    // ---- update (i.e., the registered value).
    wire signed [19:0] q   = acc[ACC_W-1:8];  // floor(acc / 256), two's compl.
    wire        [7:0]  rem = acc[7:0];        // non-negative remainder
    wire round_up = (rem > 8'h80) || ((rem == 8'h80) && q[0]);
    wire signed [20:0] rq = {q[19], q} + (round_up ? 21'sd1 : 21'sd0);

    wire sat_hi = (rq >  21'sd32767);
    wire sat_lo = (rq < -21'sd32768);
    wire signed [15:0] rres = sat_hi ?  16'sd32767 :
                              sat_lo ? -16'sd32768 : rq[15:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            acc       <= '0;
            res       <= '0;
            res_valid <= 1'b0;
            ovf       <= 1'b0;
        end else begin
            res_valid <= rd;
            if (rd) res <= rres;

            // A saturating readout sets ovf even if clr is asserted the
            // same cycle (set dominates same-cycle clear).
            ovf <= ((clr ? 1'b0 : ovf) | (rd && (sat_hi || sat_lo)));

            // Accumulator update priority: clr+en -> product alone.
            if (clr && en)  acc <= prod_x;
            else if (clr)   acc <= '0;
            else if (en)    acc <= acc + prod_x;
        end
    end

endmodule
