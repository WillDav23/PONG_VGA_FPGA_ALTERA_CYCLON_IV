module render (
    input      [9:0] pixelx_i,
    input      [9:0] pixely_i,
    input      [9:0] ballx_i,
    input      [9:0] bally_i,
    input      [9:0] pad1y_i,
    input      [9:0] pad2y_i,
    input      [3:0] score1_i,
    input      [3:0] score2_i,
    input            video_on_i,
    output reg       r_o,
    output reg       g_o,
    output reg       b_o
);

  // CONTROL DE LÍMITES GEOMÉTRICOS
  wire is_ball  = (pixelx_i >= ballx_i - 10) && (pixelx_i <= ballx_i + 10) &&
                  (pixely_i >= bally_i - 10) && (pixely_i <= bally_i + 10);

  wire is_pad1  = (pixelx_i >= 30)  && (pixelx_i <= 60)  &&
                  (pixely_i >= pad1y_i) && (pixely_i <= pad1y_i + 80);

  wire is_pad2  = (pixelx_i >= 580) && (pixelx_i <= 610) &&
                  (pixely_i >= pad2y_i) && (pixely_i <= pad2y_i + 80);

  // SCORE 1: Segmentos individuales
  wire is_h1_1 = (pixelx_i >= 275) && (pixelx_i <= 300) && (pixely_i >= 20) && (pixely_i <= 30);
  wire is_h2_1 = (pixelx_i >= 275) && (pixelx_i <= 300) && (pixely_i >= 55) && (pixely_i <= 65);
  wire is_h3_1 = (pixelx_i >= 275) && (pixelx_i <= 300) && (pixely_i >= 90) && (pixely_i <= 100);
  wire is_v1_1 = (pixelx_i >= 265) && (pixelx_i <= 275) && (pixely_i >= 30) && (pixely_i <= 55);
  wire is_v2_1 = (pixelx_i >= 265) && (pixelx_i <= 275) && (pixely_i >= 65) && (pixely_i <= 90);
  wire is_v3_1 = (pixelx_i >= 300) && (pixelx_i <= 310) && (pixely_i >= 30) && (pixely_i <= 55);
  wire is_v4_1 = (pixelx_i >= 300) && (pixelx_i <= 310) && (pixely_i >= 65) && (pixely_i <= 90);
  reg is_score_1;

  // SCORE 2: Segmentos individuales
  wire is_h1_2 = (pixelx_i >= 350) && (pixelx_i <= 375) && (pixely_i >= 20) && (pixely_i <= 30);
  wire is_h2_2 = (pixelx_i >= 350) && (pixelx_i <= 375) && (pixely_i >= 55) && (pixely_i <= 65);
  wire is_h3_2 = (pixelx_i >= 350) && (pixelx_i <= 375) && (pixely_i >= 90) && (pixely_i <= 100);
  wire is_v1_2 = (pixelx_i >= 375) && (pixelx_i <= 385) && (pixely_i >= 30) && (pixely_i <= 55);
  wire is_v2_2 = (pixelx_i >= 375) && (pixelx_i <= 385) && (pixely_i >= 65) && (pixely_i <= 90);
  wire is_v3_2 = (pixelx_i >= 340) && (pixelx_i <= 350) && (pixely_i >= 30) && (pixely_i <= 55);
  wire is_v4_2 = (pixelx_i >= 340) && (pixelx_i <= 350) && (pixely_i >= 65) && (pixely_i <= 90);
  reg is_score_2;

  // MÁQUINA DE DIBUJO
  always @(*) begin
    if (!video_on_i) begin
      // Si estamos en zona de sincronismo/porches, salidas estrictamente en '0'
      r_o = 0;
      g_o = 0;
      b_o = 0;
    end else begin
      if (is_ball) begin
        r_o = 1;
        g_o = 1;
        b_o = 1;  // Pelota blanca
      end else if (is_pad1) begin
        r_o = 1;
        g_o = 1;
        b_o = 1;  // Raqueta 1 blanca
      end else if (is_pad2) begin
        r_o = 1;
        g_o = 1;
        b_o = 1;  // Raqueta 2 blanca
      end else if (is_score_1) begin
        r_o = 1;
        g_o = 1;
        b_o = 1;  // Número 1 blanco
      end else if (is_score_2) begin
        r_o = 1;
        g_o = 1;
        b_o = 1;  // Número 2 blanco
      end else begin
        r_o = 0;
        g_o = 0;
        b_o = 0;  // CORREGIDO: Fondo negro por defecto
      end
    end
  end

  // DECODIFICADOR DEL 7 SEGMENTOS VIRTUAL
  always @(*) begin
    case (score1_i)
      4'd0: is_score_1 = (is_h1_1 || is_h3_1 || is_v1_1 || is_v2_1 || is_v3_1 || is_v4_1);
      4'd1: is_score_1 = (is_v3_1 || is_v4_1);
      4'd2: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v3_1 || is_v2_1);
      4'd3: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v3_1 || is_v4_1);
      4'd4: is_score_1 = (is_h2_1 || is_v1_1 || is_v3_1 || is_v4_1);
      4'd5: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v1_1 || is_v4_1);
      4'd6: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v1_1 || is_v2_1 || is_v4_1);
      4'd7: is_score_1 = (is_h1_1 || is_v3_1 || is_v4_1);
      4'd8: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v1_1 || is_v2_1 || is_v3_1 || is_v4_1);
      4'd9: is_score_1 = (is_h1_1 || is_h2_1 || is_v1_1 || is_v3_1 || is_v4_1);
      default: is_score_1 = 1'b0;
    endcase

    case (score2_i)
      4'd0: is_score_2 = (is_h1_2 || is_h3_2 || is_v1_2 || is_v2_2 || is_v3_2 || is_v4_2);
      4'd1: is_score_2 = (is_v1_2 || is_v2_2);
      4'd2: is_score_2 = (is_h1_2 || is_h2_2 || is_h3_2 || is_v1_2 || is_v4_2);
      4'd3: is_score_2 = (is_h1_2 || is_h2_2 || is_h3_2 || is_v1_2 || is_v2_2);
      4'd4: is_score_2 = (is_h2_2 || is_v3_2 || is_v1_2 || is_v2_2);
      4'd5: is_score_2 = (is_h1_2 || is_h2_2 || is_h3_2 || is_v3_2 || is_v2_2);
      4'd6: is_score_2 = (is_h1_2 || is_h2_2 || is_h3_2 || is_v3_2 || is_v4_2 || is_v2_2);
      4'd7: is_score_2 = (is_h1_2 || is_v1_2 || is_v2_2);
      4'd8: is_score_2 = (is_h1_2 || is_h2_2 || is_h3_2 || is_v3_2 || is_v4_2 || is_v1_2 || is_v2_2);
      4'd9: is_score_2 = (is_h1_2 || is_h2_2 || is_v3_2 || is_v1_2 || is_v2_2);
      default: is_score_2 = 1'b0;
    endcase
  end

endmodule

