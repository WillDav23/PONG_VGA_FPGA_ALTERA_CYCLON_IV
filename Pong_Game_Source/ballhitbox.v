module ballhitbox (
    input clk_i,
    input rst_i,
    input [9:0] pixelx_i,
    input [9:0] pixely_i,
    input [9:0] pad1y_i,
    input [9:0] pad2y_i,
    output reg [9:0] ballx_o,
    output reg [9:0] bally_o,
    output reg score1,
    output reg score2
);

  parameter integer TamanoPad = 10'd80;
  parameter integer LimitPad1 = 10'd70;
  parameter integer LimitPad2 = 10'd570;
  parameter integer Centerx = 10'd320;
  parameter integer Centery = 10'd240;


  reg signed [9:0] vx, vy;


  wire hit_pad1 = (ballx_o <= LimitPad1) && (bally_o >= pad1y_i) && (bally_o <= pad1y_i + TamanoPad);
  wire hit_pad2 = (ballx_o >= LimitPad2) && (bally_o >= pad2y_i) && (bally_o <= pad2y_i + TamanoPad);
  wire hit_top_bottom = (bally_o <= 10'd10) || (bally_o >= 10'd470);


  wire point1 = (ballx_o >= 10'd629);
  wire point2 = (ballx_o <= 10'd10);

  // Registro de velocidad de la pelota (Divisor de reloj)
  reg [21:0] speed_cnt;
  parameter integer SpeedDiv = 22'd500000;  // Menor número = juego más rápido

  // Registro y parámetros para el tiempo de pausa tras un gol
  reg [24:0] pausa_count;
  parameter integer TiempoDePausa = 25'd25000000;  // ~0.625 segundos a 40MHz o 1s a 25MHz

  reg estado_juego;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      ballx_o      <= Centerx;
      bally_o      <= Centery;
      score1       <= 1'd0;
      score2       <= 1'd0;
      speed_cnt    <= 22'd0;
      pausa_count  <= 25'd0;
      estado_juego <= 1'b0;  // Arranca jugando de inmediato
      vx           <= 10'sd2;
      vy           <= 10'sd2;
    end else begin
      // ESTADO 1: JUEGO EN PAUSA (Congela la pantalla tras un punto)
      if (estado_juego == 1'b1) begin
        if (pausa_count == TiempoDePausa) begin
          pausa_count  <= 25'd0;
          estado_juego <= 1'b0;
        end else begin
          pausa_count <= pausa_count + 25'd1;
          ballx_o <= Centerx;
          bally_o <= Centery;
        end
      end  // ESTADO 0: JUEGO ACTIVO (Movimiento y colisiones normales
     // ESTADO 0: JUEGO ACTIVO (Movimiento y colisiones normales)
      else begin
        if (speed_cnt == SpeedDiv) begin
          speed_cnt <= 22'd0;

          if (point1 || point2) begin
            score1 <= point1;
            score2 <= point2;

            vx <= point1 ? -10'sd2 : 10'sd2;
            vy <= point2 ? -10'sd2 : 10'sd2;

            estado_juego <= 1'b1;
            pausa_count <= 25'd0;
          end else begin

            // 1. Detección y rebote en las raquetas
            if (hit_pad1) begin
              vx <= 10'sd2;  // Rebota fijo hacia la derecha
            end else if (hit_pad2) begin
              vx <= -10'sd2; // Rebota fijo hacia la izquierda
            end
            
            // 2. CORRECCIÓN: Rebote en bordes con desatascador físico
            if (bally_o <= 10'd10) begin
              vy <= 10'sd2;       // Forzar dirección hacia abajo
              bally_o <= 10'd12;  // CORREGIDO: Empuja la pelota hacia abajo para sacarla del borde
            end else if (bally_o >= 10'd470) begin
              vy <= -10'sd2;      // Forzar dirección hacia arriba
              bally_o <= 10'd468; // CORREGIDO: Empuja la pelota hacia arriba para sacarla del borde
            end else begin
              // Si no está tocando los bordes, se mueve normalmente con su velocidad actual
              bally_o <= bally_o + vy;
            end

            // El eje X se mueve normal
            ballx_o <= ballx_o + vx;
          end
        end else begin
          speed_cnt <= speed_cnt + 22'd1;
          
          // CRÍTICO: Mantener los valores de score en 0 mientras se juega
          score1 <= 1'b0;
          score2 <= 1'b0;
        end
      end
  end
end
endmodule

