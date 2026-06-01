module pad (
    input clk_i,
    input rst_i,
    input btnup_i,
    input btndown_i,
    output reg [9:0] pady_o
);

  reg [19:0] contador;
  parameter integer Velocidad    = 20'd1000000;
  parameter integer TamanoPad    = 10'd80;
  parameter integer MaxPantallaY = 10'd480;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      pady_o   <= 10'd200; // Centrado inicial más natural para 480p (240 - 40)
      contador <= 20'd0;
    end else begin
      if (contador == Velocidad) begin
        contador <= 20'd0;
        // CORREGIDO: Se cambia el límite a > 2 para evitar que la resta dé negativo
        if (btnup_i && (pady_o > 10'd2)) begin
          pady_o <= pady_o - 10'd10;
        end
        // CORREGIDO: Se usa 'else if' para evitar escrituras simultáneas en el registro
        else if (btndown_i && (pady_o < (MaxPantallaY - TamanoPad))) begin
          pady_o <= pady_o + 10'd10;
        end
      end else begin
        contador <= contador + 20'd1;
      end
    end
  end

endmodule
