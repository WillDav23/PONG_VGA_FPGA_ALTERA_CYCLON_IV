// =====================================================================
// Módulo: ballhitbox
// Función: "Motor de física" del juego.
//  - Calcula la posición (X,Y) de la pelota, cuadro a cuadro
//  - Detecta colisiones con las raquetas y con los bordes superior/inferior
//  - Detecta cuando un jugador anota un punto (la pelota sale por un lado)
//  - Maneja una breve pausa de "celebración" tras cada gol antes de reanudar
// =====================================================================
module ballhitbox (
    input clk_i,              // Reloj del sistema
    input rst_i,              // Reset asíncrono
    input [9:0] pixelx_i,     // Coordenada X del barrido VGA (no usada en la física)
    input [9:0] pixely_i,     // Coordenada Y del barrido VGA (no usada en la física)
    input [9:0] pad1y_i,      // Posición Y actual de la raqueta del jugador 1 (izquierda)
    input [9:0] pad2y_i,      // Posición Y actual de la raqueta del jugador 2 (derecha)
    output reg [9:0] ballx_o, // Posición X actual de la pelota
    output reg [9:0] bally_o, // Posición Y actual de la pelota
    output reg score1,        // Pulso de 1 ciclo: se activa cuando anota el jugador 1
    output reg score2         // Pulso de 1 ciclo: se activa cuando anota el jugador 2
);

  // ------------------------------------------------------------
  // PARÁMETROS GEOMÉTRICOS DEL CAMPO DE JUEGO
  // ------------------------------------------------------------
  parameter integer TamanoPad = 10'd80;   // Alto de cada raqueta (en píxeles)
  parameter integer LimitPad1 = 10'd70;   // Coordenada X donde está la raqueta izquierda
  parameter integer LimitPad2 = 10'd570;  // Coordenada X donde está la raqueta derecha
  parameter integer Centerx   = 10'd320;  // Centro horizontal de la pantalla (640/2)
  parameter integer Centery   = 10'd240;  // Centro vertical de la pantalla (480/2)

  // Vector de velocidad de la pelota, CON SIGNO para poder representar
  // movimiento negativo (izquierda/arriba) o positivo (derecha/abajo)
  reg signed [9:0] vx, vy;

  // ------------------------------------------------------------
  // DETECCIÓN DE COLISIONES (lógica combinacional permanente,
  // se recalcula en cada instante con los valores actuales)
  // ------------------------------------------------------------

  // hit_pad1: la pelota está sobre la raqueta izquierda si:
  //   - su X ya alcanzó/pasó la posición de esa raqueta
  //   - su Y está dentro del rango vertical que cubre la raqueta
  wire hit_pad1 = (ballx_o <= LimitPad1) &&
                  (bally_o >= pad1y_i)   &&
                  (bally_o <= pad1y_i + TamanoPad);

  // hit_pad2: análogo, pero para la raqueta derecha
  wire hit_pad2 = (ballx_o >= LimitPad2) &&
                  (bally_o >= pad2y_i)   &&
                  (bally_o <= pad2y_i + TamanoPad);

  // hit_top_bottom: la pelota tocó el borde superior o inferior.
  // (Se calcula como referencia; el rebote real más abajo vuelve
  // a comparar bally_o directamente para poder reposicionar la pelota)
  wire hit_top_bottom = (bally_o <= 10'd10) || (bally_o >= 10'd470);

  // ------------------------------------------------------------
  // DETECCIÓN DE GOL: la pelota cruzó por completo un lado de la pantalla
  // ------------------------------------------------------------
  wire point1 = (ballx_o >= 10'd629);  // Pelota llegó al borde derecho -> punto para J1
  wire point2 = (ballx_o <= 10'd10);   // Pelota llegó al borde izquierdo -> punto para J2

  // ------------------------------------------------------------
  // DIVISOR DE VELOCIDAD DE LA PELOTA
  // La posición de la pelota solo se actualiza un "paso" cada
  // SpeedDiv ciclos de reloj. Menor SpeedDiv = pelota más rápida.
  // ------------------------------------------------------------
  reg [21:0] speed_cnt;
  parameter integer SpeedDiv = 22'd500000;

  // ------------------------------------------------------------
  // TEMPORIZADOR DE PAUSA TRAS UN GOL
  // Mantiene la pelota congelada en el centro durante un tiempo
  // (aprox. 1 segundo) para dar feedback visual antes de reanudar.
  // ------------------------------------------------------------
  reg [24:0] pausa_count;
  parameter integer TiempoDePausa = 25'd25000000;

  // Máquina de estados de 1 bit:
  //   0 = JUGANDO  (movimiento normal y colisiones activas)
  //   1 = EN PAUSA (pelota congelada en el centro tras un gol)
  reg estado_juego;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      // -------------------------------------------------------
      // ESTADO INICIAL TRAS RESET
      // -------------------------------------------------------
      ballx_o      <= Centerx;  // Pelota arranca en el centro de la pantalla
      bally_o      <= Centery;
      score1       <= 1'd0;
      score2       <= 1'd0;
      speed_cnt    <= 22'd0;
      pausa_count  <= 25'd0;
      estado_juego <= 1'b0;     // Arranca jugando de inmediato (sin pausa)
      vx           <= 10'sd2;   // Velocidad inicial: +2 en X (hacia la derecha)
      vy           <= 10'sd2;   // Velocidad inicial: +2 en Y (hacia abajo)
    end else begin

      // =========================================================
      // ESTADO 1: JUEGO EN PAUSA (justo después de un gol)
      // =========================================================
      if (estado_juego == 1'b1) begin
        if (pausa_count == TiempoDePausa) begin
          // Se cumplió el tiempo de pausa -> volver a jugar
          pausa_count  <= 25'd0;
          estado_juego <= 1'b0;
        end else begin
          // Mientras dura la pausa: avanzar el temporizador
          // y mantener la pelota fija en el centro de la pantalla
          pausa_count <= pausa_count + 25'd1;
          ballx_o <= Centerx;
          bally_o <= Centery;
        end

      // =========================================================
      // ESTADO 0: JUEGO ACTIVO (movimiento normal + colisiones)
      // =========================================================
      end else begin

        // -----------------------------------------------------
        // DIVISOR DE VELOCIDAD: solo se actualiza la posición
        // cada "SpeedDiv" ciclos de reloj
        // -----------------------------------------------------
        if (speed_cnt == SpeedDiv) begin
          speed_cnt <= 22'd0;  // Reinicia el contador de velocidad

          // ---------------------------------------------------
          // ¿ALGUIEN ANOTÓ? (la pelota salió por un lado)
          // ---------------------------------------------------
          if (point1 || point2) begin
            score1 <= point1;  // Pulso de 1 ciclo si J1 anotó
            score2 <= point2;  // Pulso de 1 ciclo si J2 anotó

            // La pelota saldrá disparada hacia el jugador que
            // recibió el gol (dirección inicial del próximo saque)
            vx <= point1 ? -10'sd2 : 10'sd2;
            vy <= point2 ? -10'sd2 : 10'sd2;

            // Se activa la pausa de celebración / reposicionamiento
            estado_juego <= 1'b1;
            pausa_count <= 25'd0;

          end else begin
            // -------------------------------------------------
            // SIN GOL: revisar colisiones normales y mover la pelota
            // -------------------------------------------------

            // 1. REBOTE EN LAS RAQUETAS (afecta el eje X)
            if (hit_pad1) begin
              vx <= 10'sd2;    // Chocó con raqueta izquierda -> rebota a la derecha
            end else if (hit_pad2) begin
              vx <= -10'sd2;   // Chocó con raqueta derecha -> rebota a la izquierda
            end
            // (Si no choca con ninguna raqueta, vx conserva su valor)

            // 2. REBOTE EN BORDES SUPERIOR/INFERIOR (afecta el eje Y)
            //    + "desatascador físico": además de invertir la
            //    velocidad, se reposiciona la pelota un poco lejos
            //    del borde, para que no quede vibrando/atascada
            //    rebotando indefinidamente en el mismo límite.
            if (bally_o <= 10'd10) begin
              vy <= 10'sd2;        // Forzar movimiento hacia abajo
              bally_o <= 10'd12;   // Empujar la pelota lejos del borde superior
            end else if (bally_o >= 10'd470) begin
              vy <= -10'sd2;       // Forzar movimiento hacia arriba
              bally_o <= 10'd468;  // Empujar la pelota lejos del borde inferior
            end else begin
              // Caso normal: ni gol ni rebote vertical -> avanza en Y
              bally_o <= bally_o + vy;
            end

            // El eje X siempre avanza según su velocidad actual
            // (la original, o la recién invertida por el rebote en raqueta)
            ballx_o <= ballx_o + vx;
          end

        end else begin
          // Mientras no se llega al límite del divisor de velocidad,
          // solo se incrementa el contador...
          speed_cnt <= speed_cnt + 22'd1;

          // ...y se mantienen apagados los pulsos de gol, para que
          // score1/score2 sean pulsos de UN SOLO ciclo (no niveles
          // sostenidos que harían que pulsecounter cuente de más)
          score1 <= 1'b0;
          score2 <= 1'b0;
        end
      end
    end
  end
endmodule
