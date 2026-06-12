// =====================================================================
// Módulo: pad
// Función: Controla la posición vertical (Y) de UNA raqueta.
// Se instancia DOS VECES en top.v (una para cada jugador), cada vez
// con sus propios botones de entrada y su propia posición de salida.
// Mueve la raqueta hacia arriba/abajo según los botones, respetando
// los límites superior e inferior de la pantalla.
// =====================================================================
module pad (
    input clk_i,             // Reloj del sistema (25 MHz)
    input rst_i,             // Reset asíncrono
    input btnup_i,           // Entrada: comando "subir" (botón o Bluetooth)
    input btndown_i,         // Entrada: comando "bajar" (botón o Bluetooth)
    output reg [9:0] pady_o  // Salida: posición vertical actual de la raqueta
);

  // Contador interno usado como temporizador / divisor de frecuencia
  reg [19:0] contador;

  // ------------------------------------------------------------
  // PARÁMETROS DE CONFIGURACIÓN
  // ------------------------------------------------------------
  parameter integer Velocidad    = 20'd1000000;  // Ciclos de reloj entre cada paso de movimiento
  parameter integer TamanoPad    = 10'd80;       // Alto de la raqueta en píxeles
  parameter integer MaxPantallaY = 10'd480;      // Alto total de la pantalla (zona vertical visible)

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      // Posición inicial: raqueta centrada verticalmente
      // (240 es el centro de 480; se resta la mitad del alto: 240-40=200)
      pady_o   <= 10'd200;
      contador <= 20'd0;
    end else begin

      // ----------------------------------------------------------
      // DIVISOR DE FRECUENCIA / TEMPORIZADOR DE MOVIMIENTO
      // La raqueta solo se mueve cuando "contador" alcanza "Velocidad".
      // Sin esto, la raqueta se movería a 25 MHz: sería instantánea
      // e imposible de controlar/ver.
      // ----------------------------------------------------------
      if (contador == Velocidad) begin
        contador <= 20'd0;  // Reinicia el temporizador para el próximo paso

        // --------------------------------------------------------
        // MOVIMIENTO HACIA ARRIBA
        // Condición doble:
        //  1) btnup_i activo
        //  2) pady_o > 2  -> evita que pady_o-10 produzca un valor
        //     negativo, que en un registro sin signo se "desborda"
        //     (underflow) y se convierte en un número gigante,
        //     haciendo que la raqueta "teletransporte" hacia abajo.
        // --------------------------------------------------------
        if (btnup_i && (pady_o > 10'd2)) begin
          pady_o <= pady_o - 10'd10;  // Sube 10 píxeles

        // --------------------------------------------------------
        // MOVIMIENTO HACIA ABAJO
        // Se usa 'else if' (no un 'if' independiente) para que,
        // si por error llegaran ambos botones activos a la vez,
        // solo se aplique UNA asignación a pady_o por ciclo
        // (evita conflictos de escritura sobre el mismo registro).
        //
        // El límite (MaxPantallaY - TamanoPad) asegura que la
        // raqueta no se salga por el borde inferior de la pantalla.
        // --------------------------------------------------------
        end else if (btndown_i && (pady_o < (MaxPantallaY - TamanoPad))) begin
          pady_o <= pady_o + 10'd10;  // Baja 10 píxeles
        end
        // Si no se cumple ninguna condición (no hay botones, o ya
        // se llegó al límite), pady_o se mantiene sin cambios.

      end else begin
        // Mientras no se alcanza el límite del temporizador,
        // solo se incrementa el contador interno
        contador <= contador + 20'd1;
      end
    end
  end

endmodule
