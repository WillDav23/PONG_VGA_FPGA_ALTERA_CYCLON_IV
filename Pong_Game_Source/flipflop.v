module flipflop(
    input  wire clk_i,
    input  wire rst_i,
    input  wire dato_i, 
    output reg  dato_o  
);

    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            dato_o <= 1'b0; 
        end else begin
            dato_o <= dato_i; 
        end
    end

endmodule

