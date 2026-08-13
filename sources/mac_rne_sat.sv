`timescale 1ns/1ps
//
// mac_rne_sat -- implement your golden solution in this file per
// docs/spec.md, and push it to your fork's mac_rne_sat_golden branch.
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

    logic signed [15:0] p,  res_int;
    logic unsigned [7:0] r;
    logic signed [27:0] acc_next, snapshot, q, rounded;
    // Product
    assign p = (a * b);
    // Accumulator
    always @(posedge clk) begin
        if (rst) acc_next <= 28'd0;
        else begin
            case ({clr, en})
                2'b00: acc_next <= acc_next;
                2'b01: acc_next <= acc_next + {{12{p[15]}},p};
                2'b10: acc_next <= 28'd0;
                2'b11: acc_next <= {{12{p[15]}},p};
            endcase
        end
    end
    
    assign snapshot = rd ? acc_next : 28'd0;
    assign q = $floor(snapshot / 256.0);
    assign r = snapshot - (q * 256.0);
    
    // Rounding
    assign rounded = (r < 128) ? q : (r > 128) ? q + 1 : (q[0]) ? q + 1 : q;

    // Saturation
    assign res_int = (rounded > 32767) ? 32767 : (rounded < -32768) ? -32768 : rounded[15:0];

    // Readout
    always @(posedge clk) begin
        if (rst) begin 
            res_valid <= 1'b0; 
            res <= 16'h0; 
            end
        else begin 
            res_valid <= rd; 
            res <= rd ? res_int : res; 
            end
    end

    always @(posedge clk) begin
        if (rst) ovf <= 1'b0;
        else if (rd && (rounded > 32767 || rounded < -32768)) ovf <= 1'b1;
        else if (!rd && clr ) ovf <= 1'b0;
        else ovf <= ovf;
    end
endmodule
