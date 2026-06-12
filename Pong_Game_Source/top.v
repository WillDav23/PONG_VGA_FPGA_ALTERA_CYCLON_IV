// =====================================================================
// Módulo: top
// Función: Módulo de nivel superior (Top-Level Entity).
// Es el "director de orquesta" del proyecto: instancia y conecta
// TODOS los submódulos del sistema.
//
//  - pll25mhz     -> genera el reloj de píxel (25MHz) desde 50MHz
//  - vga          -> genera coordenadas de barrido y sincronismos
//  - pad (x2)     -> controla la posición de cada raqueta
//  - ballhitbox   -> física/colisiones de la pelota y puntaje
//  - pulsecounter (x2) -> marcadores acumulados de cada jugador
//  - render       -> decide el color de cada píxel
//  - flipflop (x5)-> registro final anti-glitch antes de los pines
//  - uart_rx      -> recepción serie del módulo Bluetooth (HC-05/06)
// =====================================================================
module top (
    input  clk,       // Reloj físico de entrada (50MHz, oscilador de la placa)
    input  rst,       // Señal/botón de reset del sistema
    input  UART_RX,   // Línea de recepción serie del módulo Bluetooth
    output hsync_o,   // Salida VGA: sincronismo horizontal
    output vsync_o,   // Salida VGA: sincronismo vertical
    output clk_o,     // Salida de prueba: copia del reloj de 25MHz (para osciloscopio)
    output r_o,       // Salida VGA: canal de color Rojo
    output g_o,       // Salida VGA: canal de color Verde
    output b_o        // Salida VGA: canal de color Azul
);

  // ------------------------------------------------------------
  // 1. SEÑALES INTERNAS (CABLES DE CONEXIÓN ENTRE MÓDULOS)
  // ------------------------------------------------------------

  wire       clock25mhz;  // Reloj de píxel (25MHz) generado por el PLL
  wire [9:0] pixelx;       // Coordenada X actual del barrido VGA
  wire [9:0] pixely;       // Coordenada Y actual del barrido VGA
  wire       hsync;         // Señal H-SYNC "cruda" (antes del registro final)
  wire       vsync;         // Señal V-SYNC "cruda" (antes del registro final)
  wire       video_on;      // 1 = el barrido está dentro del área visible (640x480)

  // Posiciones de los objetos del juego
  wire [9:0] pad1_y;  // Posición Y de la raqueta del jugador 1 (izquierda)
  wire [9:0] pad2_y;  // Posición Y de la raqueta del jugador 2 (derecha)
  wire [9:0] ball_x;  // Posición X de la pelota
  wire [9:0] ball_y;  // Posición Y de la pelota

  // Señales de puntuación
  wire       score1_pulso;  // Pulso de gol del jugador 1 (proviene de ballhitbox)
  wire       score2_pulso;  // Pulso de gol del jugador 2 (proviene de ballhitbox)
  wire [3:0] score1_total;  // Marcador acumulado (0-9) del jugador 1
  wire [3:0] score2_total;  // Marcador acumulado (0-9) del jugador 2

  // Señales de color "crudas", antes de pasar por el registro final
  wire       r;
  wire       g;
  wire       b;

  // El reloj de salida de prueba es directamente el reloj de píxel
  assign clk_o = clock25mhz;

  // ------------------------------------------------------------
  // SEÑALES PARA EL MÓDULO BLUETOOTH (UART)
  // ------------------------------------------------------------
  wire [7:0] rx_data;  // Byte recibido por la UART
  wire rx_ready;       // 1 = hay un byte nuevo disponible en rx_data

  // Registros que representan el estado "presionado / no presionado"
  // de los 4 controles virtuales (subir/bajar para cada jugador)
  reg btn_up1;
  reg btn_up2;
  reg btn_down1;
  reg btn_down2;


  // ------------------------------------------------------------
  // GENERACIÓN DEL RELOJ DE PÍXEL (25MHz)
  // ------------------------------------------------------------
`ifdef SYNTHESIS
  // En simulación con Yosys: se "puentea" el reloj de entrada
  // directamente al sistema, sin pasar por el PLL real
  // (el bloque IP altpll no es soportado por Yosys)
  assign clock25mhz = clk;
`else
  // En síntesis real con Quartus: se usa el bloque PLL dedicado
  // de la FPGA para generar 25MHz a partir de los 50MHz de entrada
  pll25mhz mi_pll (
      .clk_50mhz_i(clk),
      .clk_25mhz_o(clock25mhz)
  );
`endif


  // ------------------------------------------------------------
  // 2. MÓDULO DE TEMPORIZACIÓN VGA
  // Genera las coordenadas de barrido (pixelx, pixely) y las
  // señales de sincronismo H-SYNC / V-SYNC, además de la bandera
  // "video_on" que indica si se está en la zona visible.
  // ------------------------------------------------------------
  vga vga_principal (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .pixelx_o(pixelx),
      .pixely_o(pixely),
      .hsync_o(hsync),
      .vsync_o(vsync),
      .video_on_o(video_on)
  );


  // ------------------------------------------------------------
  // 3. LÓGICA DEL JUEGO
  // ------------------------------------------------------------

  // Raqueta del jugador 1 (izquierda): se mueve con btn_up1 / btn_down1
  pad raqueta_izq (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .btnup_i(btn_up1),
      .btndown_i(btn_down1),
      .pady_o(pad1_y)
  );

  // Raqueta del jugador 2 (derecha): se mueve con btn_up2 / btn_down2
  pad raqueta_der (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .btnup_i(btn_up2),
      .btndown_i(btn_down2),
      .pady_o(pad2_y)
  );

  // Motor de física: calcula la posición de la pelota, detecta
  // colisiones con las raquetas/bordes y genera los pulsos de gol
  ballhitbox pelota (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .pixelx_i(pixelx),
      .pixely_i(pixely),
      .pad1y_i(pad1_y),
      .pad2y_i(pad2_y),
      .ballx_o(ball_x),
      .bally_o(ball_y),
      .score1(score1_pulso),
      .score2(score2_pulso)
  );

  // Contador de puntaje del jugador 1: incrementa con cada pulso de gol
  pulsecounter cuenta_j1 (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .s_i(score1_pulso),
      .count_o(score1_total)
  );

  // Contador de puntaje del jugador 2
  pulsecounter cuenta_j2 (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .s_i(score2_pulso),
      .count_o(score2_total)
  );


  // ------------------------------------------------------------
  // 4. MOTOR GRÁFICO (RENDER)
  // Recibe la coordenada actual de barrido (pixelx, pixely) y todas
  // las posiciones/puntajes del juego, y decide qué color (r,g,b)
  // corresponde dibujar en ese píxel (pelota, raquetas, marcador o fondo)
  // ------------------------------------------------------------
  render render_principal (
      .pixelx_i  (pixelx),        // Coordenada X del barrido VGA
      .pixely_i  (pixely),        // Coordenada Y del barrido VGA
      .ballx_i   (ball_x),        // Posición de la pelota
      .bally_i   (ball_y),
      .pad1y_i   (pad1_y),        // Posición raqueta izquierda
      .pad2y_i   (pad2_y),        // Posición raqueta derecha
      .score1_i  (score1_total),  // Puntuación actual J1
      .score2_i  (score2_total),  // Puntuación actual J2
      .video_on_i(video_on),      // 1 si estamos en zona visible
      .r_o       (r),
      .g_o       (g),
      .b_o       (b)
  );


  // ------------------------------------------------------------
  // ETAPA FINAL: REGISTROS ANTI-GLITCH (flip-flops)
  // Antes de salir por los pines físicos, TODAS las señales pasan
  // por un registro síncrono adicional. Esto "alinea" en el tiempo
  // señales que llegaron por caminos combinacionales distintos
  // (con distintos retardos de propagación), evitando parpadeos
  // o ruido visual en el monitor.
  // ------------------------------------------------------------
  flipflop flip_hsync (
      .clk_i (clock25mhz),
      .rst_i (rst),
      .dato_i(hsync),
      .dato_o(hsync_o)
  );

  flipflop flip_vsync (
      .clk_i (clock25mhz),
      .rst_i (rst),
      .dato_i(vsync),
      .dato_o(vsync_o)
  );

  flipflop flip_r (
      .clk_i (clock25mhz),
      .rst_i (rst),
      .dato_i(r),
      .dato_o(r_o)
  );

  flipflop flip_g (
      .clk_i (clock25mhz),
      .rst_i (rst),
      .dato_i(g),
      .dato_o(g_o)
  );

  flipflop flip_b (
      .clk_i (clock25mhz),
      .rst_i (rst),
      .dato_i(b),
      .dato_o(b_o)
  );


  // ------------------------------------------------------------
  // 5. RECEPTOR UART (BLUETOOTH HC-05/HC-06)
  // Convierte la línea serie UART_RX en bytes (rx_data), avisando
  // con rx_ready=1 durante un ciclo cuando llega un byte nuevo.
  // Nota: este módulo usa el reloj de 50MHz directo (clk), no el
  // reloj de píxel de 25MHz.
  // ------------------------------------------------------------
  uart_rx uart0 (
      .i_clk(clk),
      .i_uart_rx(UART_RX),
      .o_wr(rx_ready),
      .o_data(rx_data)
  );

  // ------------------------------------------------------------
  // DECODIFICADOR DE COMANDOS BLUETOOTH
  // Traduce los caracteres ASCII recibidos (W/A/S/D) en señales de
  // "botón presionado" para las dos raquetas. Mientras no llegue un
  // byte nuevo, los botones mantienen su último estado (es decir,
  // se "sigue moviendo" hasta recibir otro carácter que lo detenga).
  // ------------------------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      // Al resetear, ningún botón está activo
      btn_up1   <= 1'b0;
      btn_up2   <= 1'b0;
      btn_down1 <= 1'b0;
      btn_down2 <= 1'b0;
    end else begin

      // Solo actuamos si llegó un byte nuevo por Bluetooth
      if (rx_ready) begin
        case (rx_data)
          8'h57: btn_up1   <= 1'b1;  // Carácter 'W' -> Jugador 1 sube
          8'h41: btn_up2   <= 1'b1;  // Carácter 'A' -> Jugador 2 sube
          8'h53: btn_down1 <= 1'b1;  // Carácter 'S' -> Jugador 1 baja
          8'h44: btn_down2 <= 1'b1;  // Carácter 'D' -> Jugador 2 baja
          default: begin
            // Cualquier otro carácter (p. ej. "tecla soltada")
            // apaga todos los botones: el movimiento se detiene
            btn_up1   <= 1'b0;
            btn_up2   <= 1'b0;
            btn_down1 <= 1'b0;
            btn_down2 <= 1'b0;
          end
        endcase
      end
      // Si rx_ready==0, los botones conservan su último estado

    end
  end

endmodule
