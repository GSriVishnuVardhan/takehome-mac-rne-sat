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

    logic signed [15:0] p, acc_next, snapshot, q, r, rounded;
    // Product
    always_comb p = (a * b) >>> 8;
    // Accumulator
    always_ff @(posedge clk) begin
        if (rst) acc_next <= 16'h0;
        else begin
            case ({clr, en})
                2'b00: acc_next <= acc_next;
                2'b01: acc_next <= acc_next + p;
                2'b10: acc_next <= 16'h0;
                2'b11: acc_next <= p;
            endcase
        end
    end
    
    always_ff @(posedge clk) begin
        if (rst) snapshot <= 16'h0;
        else if (rd) snapshot <= acc_next;
    end

    always_comb begin
        q = $floor(snapshot / 256);
        r = snapshot - (q * 256);
    end

    always_comb begin
        if (r < 128) rounded = q ;
        else if (r > 128) rounded = q + 1;
        else begin 
            if (q[0]) rounded = q + 1;
            else rounded = q;
        end
    end

    always_comb begin
        if (rounded > 32767) res_int = 32767;
        else if (rounded < -32768) res_int = -32768;
        else res_int = rounded;
    end

    always_ff @(posedge clk) begin
        if (rst) begin 
            rd_q <= 1'b0;
            res_valid <= 1'b0; 
            res <= 16'h0; 
            end
        else begin 
            rd_q <= rd;
            res_valid <= rd_q; 

            res <= rd_q ? res_int : res; 
            end
    end

    always_ff @(posedge clk) begin
        if (rst) ovf <= 1'b0;
        else if (rd_q && (rounded > 32767 || rounded < -32768)) ovf <= 1'b1;
        else if (!rd && clr ) ovf <= 1'b0;
        else ovf <= ovf;
    end
endmodule
