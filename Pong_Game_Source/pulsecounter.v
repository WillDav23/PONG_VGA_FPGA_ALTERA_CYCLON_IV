// =====================================================================
// Módulo: pulsecounter
// Función: Contador de puntaje (0-9) para UN jugador.
// Detecta un pulso de "gol" (flanco de subida en s_i, que llega desde
// ballhitbox) y aumenta el marcador en 1, reiniciando a 0 al pasar de 9
// (limitado a un solo dígito porque así lo espera el render de 7 segmentos).
// =====================================================================
module pulsecounter (
    input clk_i,              // Reloj del sistema
    input rst_i,              // Reset asíncrono (activo en alto)
    input s_i,                // Señal de "gol" (score1 o score2 de ballhitbox)
    output reg [3:0] count_o  // Marcador actual del jugador (0 a 9)
);

  // Registro interno: guarda el valor de s_i del ciclo anterior.
  // Sirve para comparar "antes" vs "ahora" y detectar el cambio 0->1.
  reg s_anterior;

  // Detector de flanco de subida (edge detector):
  // flanco_subida vale 1 SOLO durante el ciclo en que s_i pasa de 0 a 1.
  // Esto evita contar varias veces si s_i se queda en 1 durante varios ciclos.
  wire flanco_subida = (s_i == 1'b1) && (s_anterior == 1'b0);

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      // Reset: el marcador vuelve a 0 y se borra la "memoria" de s_i
      count_o    <= 4'd0;
      s_anterior <= 1'b0;
    end else begin
      // Guardamos el estado actual de s_i para compararlo el próximo ciclo
      s_anterior <= s_i;

      // Si justo ahora se detectó un nuevo gol (flanco de subida):
      if (flanco_subida) begin
        if (count_o == 4'd9) begin
          // Si ya estaba en 9, vuelve a 0 (límite de un dígito decimal)
          count_o <= 4'd0;
        end else begin
          // En cualquier otro caso, simplemente suma 1 al marcador
          count_o <= count_o + 4'd1;
        end
      end
      // Si no hubo flanco, count_o conserva su valor (no se le asigna nada)
    end
  end

endmodule
