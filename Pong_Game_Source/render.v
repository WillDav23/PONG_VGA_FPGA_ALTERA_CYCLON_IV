// =============================================================================
// Módulo: render.v
// Proyecto: PONG VGA - FPGA Altera Cyclone IV
// -----------------------------------------------------------------------------
// Descripción:
//   Motor de renderizado píxel a píxel para salida VGA.
//   En cada ciclo de reloj recibe las coordenadas del píxel que el cañón de
//   electrones está dibujando en ese instante (pixelx_i, pixely_i) y decide
//   qué color RGB mostrar comparando esas coordenadas con la posición de los
//   objetos del juego (pelota, raquetas y marcadores).
//
//   Toda la lógica es COMBINACIONAL (sin registros de estado propios): las
//   salidas r_o, g_o, b_o se actualizan instantáneamente ante cualquier
//   cambio en las entradas.
//
// Paleta usada:
//   Blanco  → r=1, g=1, b=1  (pelota, raquetas, dígitos del marcador)
//   Negro   → r=0, g=0, b=0  (fondo y zonas de sincronismo VGA)
// =============================================================================

module render (
    // -------------------------------------------------------------------------
    // ENTRADAS
    // -------------------------------------------------------------------------

    // Posición actual del píxel que el controlador VGA está generando.
    // Rango válido: 0–639 (X) y 0–479 (Y) en resolución 640×480.
    input      [9:0] pixelx_i,   // Coordenada horizontal del píxel actual
    input      [9:0] pixely_i,   // Coordenada vertical  del píxel actual

    // Estado dinámico del juego (actualizado cada frame por el módulo de física)
    input      [9:0] ballx_i,    // Coordenada X del centro de la pelota
    input      [9:0] bally_i,    // Coordenada Y del centro de la pelota
    input      [9:0] pad1y_i,    // Coordenada Y del borde superior de la raqueta 1 (izquierda)
    input      [9:0] pad2y_i,    // Coordenada Y del borde superior de la raqueta 2 (derecha)

    // Puntuaciones actuales de cada jugador (valores 0–9 en BCD de 4 bits)
    input      [3:0] score1_i,   // Puntuación jugador 1
    input      [3:0] score2_i,   // Puntuación jugador 2

    // Señal de habilitación de vídeo del controlador VGA.
    // Vale '1' solo cuando el cañón está en la zona visible de la pantalla.
    // Vale '0' durante los porches y pulsos de sincronismo horizontal/vertical.
    input            video_on_i,

    // -------------------------------------------------------------------------
    // SALIDAS  (1 bit por canal → paleta de 8 colores)
    // -------------------------------------------------------------------------
    output reg       r_o,        // Canal rojo
    output reg       g_o,        // Canal verde
    output reg       b_o         // Canal azul
);

// =============================================================================
// SECCIÓN 1 — DETECCIÓN GEOMÉTRICA DE OBJETOS
//
// Cada 'wire' es una expresión booleana que vale '1' si el píxel actual
// (pixelx_i, pixely_i) cae DENTRO del bounding box del objeto correspondiente.
// Al ser wires, se evalúan en paralelo en hardware puro (compuertas AND/OR).
// =============================================================================

  // ---------------------------------------------------------------------------
  // Pelota: cuadrado de 20×20 píxeles centrado en (ballx_i, bally_i).
  // Se restan/suman 10 al centro para obtener los cuatro bordes del cuadrado.
  //
  // AVISO: las restas sin signo pueden hacer underflow si ballx_i < 10 o
  // bally_i < 10 (la pelota toca el borde superior/izquierdo). En ese caso
  // la comparación >= produce un resultado incorrecto por wraparound.
  // ---------------------------------------------------------------------------
  wire is_ball  = (pixelx_i >= ballx_i - 10) && (pixelx_i <= ballx_i + 10) &&
                  (pixely_i >= bally_i - 10) && (pixely_i <= bally_i + 10);

  // ---------------------------------------------------------------------------
  // Raqueta del jugador 1 (lado izquierdo de la pantalla).
  //   Posición horizontal fija: x = 30 a 60 (30 px de ancho).
  //   Posición vertical variable: desde pad1y_i hasta pad1y_i + 80 (80 px alto).
  // ---------------------------------------------------------------------------
  wire is_pad1  = (pixelx_i >= 30)  && (pixelx_i <= 60)  &&
                  (pixely_i >= pad1y_i) && (pixely_i <= pad1y_i + 80);

  // ---------------------------------------------------------------------------
  // Raqueta del jugador 2 (lado derecho de la pantalla).
  //   Posición horizontal fija: x = 580 a 610 (30 px de ancho).
  //   Posición vertical variable: desde pad2y_i hasta pad2y_i + 80 (80 px alto).
  // ---------------------------------------------------------------------------
  wire is_pad2  = (pixelx_i >= 580) && (pixelx_i <= 610) &&
                  (pixely_i >= pad2y_i) && (pixely_i <= pad2y_i + 80);


// =============================================================================
// SECCIÓN 2 — SEGMENTOS DEL MARCADOR (display de 7 segmentos virtual)
//
// En lugar de un display físico, se dibujan los segmentos directamente en
// pantalla. Cada segmento es un pequeño rectángulo de píxeles. Si el píxel
// actual cae dentro de ese rectángulo, el wire correspondiente vale '1'.
//
// Mapa de segmentos de un dígito de 7 segmentos:
//
//    ── h1 ──        y: 20–30
//   |        |
//  v1       v3       y: 30–55
//   |        |
//    ── h2 ──        y: 55–65
//   |        |
//  v2       v4       y: 65–90
//   |        |
//    ── h3 ──        y: 90–100
//
// Score 1 ocupa la zona X: 265–310 (lado izquierdo del centro de pantalla).
// Score 2 ocupa la zona X: 340–385 (lado derecho del centro de pantalla).
// Ambos en la franja superior Y: 20–100.
// =============================================================================

  // ---------------------------------------------------------------------------
  // Segmentos del dígito del JUGADOR 1
  // ---------------------------------------------------------------------------

  // Segmentos horizontales (franjas anchas)
  wire is_h1_1 = (pixelx_i >= 275) && (pixelx_i <= 300) && (pixely_i >= 20)  && (pixely_i <= 30);  // Superior
  wire is_h2_1 = (pixelx_i >= 275) && (pixelx_i <= 300) && (pixely_i >= 55)  && (pixely_i <= 65);  // Medio
  wire is_h3_1 = (pixelx_i >= 275) && (pixelx_i <= 300) && (pixely_i >= 90)  && (pixely_i <= 100); // Inferior

  // Segmentos verticales izquierdos
  wire is_v1_1 = (pixelx_i >= 265) && (pixelx_i <= 275) && (pixely_i >= 30)  && (pixely_i <= 55);  // Arriba-izquierda
  wire is_v2_1 = (pixelx_i >= 265) && (pixelx_i <= 275) && (pixely_i >= 65)  && (pixely_i <= 90);  // Abajo-izquierda

  // Segmentos verticales derechos
  wire is_v3_1 = (pixelx_i >= 300) && (pixelx_i <= 310) && (pixely_i >= 30)  && (pixely_i <= 55);  // Arriba-derecha
  wire is_v4_1 = (pixelx_i >= 300) && (pixelx_i <= 310) && (pixely_i >= 65)  && (pixely_i <= 90);  // Abajo-derecha

  // Resultado final: '1' si el píxel pertenece a algún segmento activo del dígito 1
  reg is_score_1;

  // ---------------------------------------------------------------------------
  // Segmentos del dígito del JUGADOR 2
  //
  // NOTA: los roles de v1/v2 y v3/v4 están intercambiados respecto al Score 1.
  // En Score 2: v1/v2 son los segmentos del lado DERECHO y v3/v4 del IZQUIERDO.
  // Esto se refleja en el decodificador case() de más abajo, donde el dígito '1'
  // usa (is_v1_2 || is_v2_2) en Score 2 pero (is_v3_1 || is_v4_1) en Score 1.
  // ---------------------------------------------------------------------------

  // Segmentos horizontales (misma franja Y que Score 1)
  wire is_h1_2 = (pixelx_i >= 350) && (pixelx_i <= 375) && (pixely_i >= 20)  && (pixely_i <= 30);  // Superior
  wire is_h2_2 = (pixelx_i >= 350) && (pixelx_i <= 375) && (pixely_i >= 55)  && (pixely_i <= 65);  // Medio
  wire is_h3_2 = (pixelx_i >= 350) && (pixelx_i <= 375) && (pixely_i >= 90)  && (pixely_i <= 100); // Inferior

  // Segmentos verticales — derecha del dígito 2 (mayor X)
  wire is_v1_2 = (pixelx_i >= 375) && (pixelx_i <= 385) && (pixely_i >= 30)  && (pixely_i <= 55);  // Arriba-derecha
  wire is_v2_2 = (pixelx_i >= 375) && (pixelx_i <= 385) && (pixely_i >= 65)  && (pixely_i <= 90);  // Abajo-derecha

  // Segmentos verticales — izquierda del dígito 2 (menor X)
  wire is_v3_2 = (pixelx_i >= 340) && (pixelx_i <= 350) && (pixely_i >= 30)  && (pixely_i <= 55);  // Arriba-izquierda
  wire is_v4_2 = (pixelx_i >= 340) && (pixelx_i <= 350) && (pixely_i >= 65)  && (pixely_i <= 90);  // Abajo-izquierda

  // Resultado final: '1' si el píxel pertenece a algún segmento activo del dígito 2
  reg is_score_2;


// =============================================================================
// SECCIÓN 3 — MÁQUINA DE DIBUJO (árbitro de color por píxel)
//
// Este bloque always decide el color final del píxel actual.
// La cadena if-else define la PRIORIDAD de pintado:
//   1. Zona de sincronismo VGA (fuera de pantalla visible) → negro absoluto
//   2. Pelota
//   3. Raqueta 1
//   4. Raqueta 2
//   5. Dígito del Score 1
//   6. Dígito del Score 2
//   7. Fondo (ningún objeto) → negro
//
// Como todos los objetos son blancos, el orden solo importaría si se usaran
// colores distintos. La estructura if-else ya lo prepara para esa expansión.
// =============================================================================

  always @(*) begin
    if (!video_on_i) begin
      // -----------------------------------------------------------------------
      // Zona de porches / pulsos de sincronismo VGA.
      // En este período el monitor no muestra imagen; forzar RGB=000 es
      // obligatorio para no interferir con las señales de sincronismo.
      // -----------------------------------------------------------------------
      r_o = 0;
      g_o = 0;
      b_o = 0;

    end else begin
      // -----------------------------------------------------------------------
      // Zona visible de la pantalla: evaluar a qué objeto pertenece el píxel.
      // -----------------------------------------------------------------------

      if (is_ball) begin
        // Pelota — color blanco
        r_o = 1;
        g_o = 1;
        b_o = 1;

      end else if (is_pad1) begin
        // Raqueta del jugador 1 — color blanco
        r_o = 1;
        g_o = 1;
        b_o = 1;

      end else if (is_pad2) begin
        // Raqueta del jugador 2 — color blanco
        r_o = 1;
        g_o = 1;
        b_o = 1;

      end else if (is_score_1) begin
        // Segmento activo del dígito del jugador 1 — color blanco
        r_o = 1;
        g_o = 1;
        b_o = 1;

      end else if (is_score_2) begin
        // Segmento activo del dígito del jugador 2 — color blanco
        r_o = 1;
        g_o = 1;
        b_o = 1;

      end else begin
        // El píxel no pertenece a ningún objeto → fondo negro
        r_o = 0;
        g_o = 0;
        b_o = 0;
      end

    end
  end


// =============================================================================
// SECCIÓN 4 — DECODIFICADOR DE 7 SEGMENTOS VIRTUAL
//
// Traduce el valor numérico de la puntuación (0–9) en un patrón de segmentos
// encendidos, exactamente igual que un decodificador BCD físico (ej. 74LS47).
//
// Para cada dígito, is_score_X vale '1' si el píxel actual cae en AL MENOS
// uno de los segmentos que deben estar encendidos para representar ese número.
//
// Tabla de segmentos por dígito:
//
//  Dígito │ h1 │ h2 │ h3 │ v1 │ v2 │ v3 │ v4
//  ───────┼────┼────┼────┼────┼────┼────┼────
//    0    │  ✓ │    │  ✓ │  ✓ │  ✓ │  ✓ │  ✓
//    1    │    │    │    │    │    │  ✓ │  ✓   (Score1: v3,v4 / Score2: v1,v2)
//    2    │  ✓ │  ✓ │  ✓ │    │  ✓ │  ✓ │
//    3    │  ✓ │  ✓ │  ✓ │    │    │  ✓ │  ✓
//    4    │    │  ✓ │    │  ✓ │    │  ✓ │  ✓
//    5    │  ✓ │  ✓ │  ✓ │  ✓ │    │    │  ✓
//    6    │  ✓ │  ✓ │  ✓ │  ✓ │  ✓ │    │  ✓
//    7    │  ✓ │    │    │    │    │  ✓ │  ✓
//    8    │  ✓ │  ✓ │  ✓ │  ✓ │  ✓ │  ✓ │  ✓
//    9    │  ✓ │  ✓ │    │  ✓ │    │  ✓ │  ✓
// =============================================================================

  always @(*) begin

    // -------------------------------------------------------------------------
    // Decodificador del SCORE 1
    // -------------------------------------------------------------------------
    case (score1_i)
      4'd0: is_score_1 = (is_h1_1 || is_h3_1 || is_v1_1 || is_v2_1 || is_v3_1 || is_v4_1);
            // Todos los segmentos excepto el medio (h2)

      4'd1: is_score_1 = (is_v3_1 || is_v4_1);
            // Solo los dos segmentos verticales derechos

      4'd2: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v3_1 || is_v2_1);
            // h1 + h2 + h3 + v3(arriba-der) + v2(abajo-izq) → forma de S inversa

      4'd3: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v3_1 || is_v4_1);
            // Los tres horizontales + columna derecha completa

      4'd4: is_score_1 = (is_h2_1 || is_v1_1 || is_v3_1 || is_v4_1);
            // Segmento medio + columna izquierda arriba + columna derecha completa

      4'd5: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v1_1 || is_v4_1);
            // Los tres horizontales + v1(arriba-izq) + v4(abajo-der)

      4'd6: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v1_1 || is_v2_1 || is_v4_1);
            // Como el 5 pero añadiendo v2(abajo-izq) — columna izquierda completa

      4'd7: is_score_1 = (is_h1_1 || is_v3_1 || is_v4_1);
            // Solo el segmento superior y la columna derecha completa

      4'd8: is_score_1 = (is_h1_1 || is_h2_1 || is_h3_1 || is_v1_1 || is_v2_1 || is_v3_1 || is_v4_1);
            // Todos los segmentos encendidos

      4'd9: is_score_1 = (is_h1_1 || is_h2_1 || is_v1_1 || is_v3_1 || is_v4_1);
            // h1 + h2 + columna izquierda arriba + columna derecha completa

      default: is_score_1 = 1'b0;
               // Valor fuera de rango (10–15): no mostrar nada
    endcase

    // -------------------------------------------------------------------------
    // Decodificador del SCORE 2
    //
    // La lógica es análoga a Score 1, pero con los nombres de segmentos
    // ajustados al mapa de posiciones del dígito 2 (zona x=340–385).
    //
    // Recuerda que en Score 2: v1/v2 son el lado DERECHO y v3/v4 el IZQUIERDO,
    // al contrario que en Score 1. Por eso el dígito '1' usa v1_2 y v2_2.
    // -------------------------------------------------------------------------
    case (score2_i)
      4'd0: is_score_2 = (is_h1_2 || is_h3_2 || is_v1_2 || is_v2_2 || is_v3_2 || is_v4_2);

      4'd1: is_score_2 = (is_v1_2 || is_v2_2);
            // En Score 2 el '1' usa la columna derecha (v1_2, v2_2)

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
// =============================================================================
// Fin del módulo render.v
// =============================================================================
