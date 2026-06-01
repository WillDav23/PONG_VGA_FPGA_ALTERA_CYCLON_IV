module pulsecounter ( 
    input clk_i,
    input rst_i,
    input s_i,
    output reg [3:0] count_o
);

  // Registro interno para guardar cómo estaba la señal en el ciclo de reloj anterior
  reg s_anterior;

  // Detector de flanco de subida: Se activa un único ciclo de reloj cuando s_i pasa de 0 a 1
  wire flanco_subida = (s_i == 1'b1) && (s_anterior == 1'b0);

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      count_o    <= 4'd0;    // El marcador se borra y arranca en cero
      s_anterior <= 1'b0;
    end else begin
      // Guardamos el estado actual de la señal para compararlo en el siguiente ciclo
      s_anterior <= s_i;

      // Si la pelota cruzó la pantalla y activó el pulso de gol:
      if (flanco_subida) begin
        if (count_o == 4'd9) begin
          count_o <= 4'd0;   // Si llega a 9, da la vuelta a 0 (límite de un dígito para tu render)
        end else begin
          count_o <= count_o + 4'd1; // Suma 1 al marcador que ya tenías guardado
        end
      end
    end
  end

endmodule
