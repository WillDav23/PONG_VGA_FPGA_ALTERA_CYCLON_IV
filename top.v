module top (
    input  clk,
    input  rst,
    input  UART_RX,
    output hsync_o,
    output vsync_o,
    output clk_o,
    output r_o,
    output g_o,
    output b_o

);


  // 1. CABLES DE CONEXIÓN INTERNA

  wire       clock25mhz;
  wire [9:0] pixelx;
  wire [9:0] pixely;
  wire       hsync;
  wire       vsync;
  wire       video_on;

  // Cables del juego (Posiciones de objetos)
  wire [9:0] pad1_y;
  wire [9:0] pad2_y;
  wire [9:0] ball_x;
  wire [9:0] ball_y;

  // Cables de lógica de puntuación
  wire       score1_pulso;  // Pulso de gol proveniente de ballhitbox
  wire       score2_pulso;  // Pulso de gol proveniente de ballhitbox
  wire [3:0] score1_total;  // Valor acumulado (0-9) para el render
  wire [3:0] score2_total;  // Valor acumulado (0-9) para el render

  // Cables intermedios de color antes de pasar por los flip-flops
  wire       r;
  wire       g;
  wire       b;
  // Asignación del reloj de salida para verificar en el osciloscopio
  assign clk_o = clock25mhz;
  //Asignacion nesesaria para el HC-06
  wire [7:0] rx_data;
  wire rx_ready;
  reg [19:0] contador;
  parameter integer Velocidad = 20'd300000;
  reg btn_up1;
  reg btn_up2;
  reg btn_down1;
  reg btn_down2;


  //--------------------------------------------------------------------------
  //--------------------------------------------------------------------------
  //--------------------------------------------------------------------------
  // INFRAESTRUCTURA DE RELOJ Y BYPASS DE SIMULACIÓN (YOSYS)
`ifdef SYNTHESIS
  // Si estás en Yosys/Simulación, puenteas el reloj de entrada directo al sistema
  assign clock25mhz = clk;
`else
  // Si estás en Quartus, el hardware real sintetiza el IP Block de Altera
  pll25mhz mi_pll (
      .clk_50mhz_i(clk),
      .clk_25mhz_o(clock25mhz)
  );
`endif
  //--------------------------------------------------------------------------
  //--------------------------------------------------------------------------
  //--------------------------------------------------------------------------


  // 2. INSTANCIACIÓN DE MÓDULOS DE INFRAESTRUCTURA (VGA)
  vga vga_principal (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .pixelx_o(pixelx),
      .pixely_o(pixely),
      .hsync_o(hsync),
      .vsync_o(vsync),
      .video_on_o(video_on)
  );


  // 3. INSTANCIACIÓN DE MÓDULOS DE LÓGICA DEL JUEGO


  // Control de la raqueta izquierda
  pad raqueta_izq (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .btnup_i(btn_up1),
      .btndown_i(btn_down1),
      .pady_o(pad1_y)
  );

  // Control de la raqueta derecha
  pad raqueta_der (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .btnup_i(btn_up2),
      .btndown_i(btn_down2),
      .pady_o(pad2_y)
  );


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

  // Contador síncrono para el Jugador 1
  pulsecounter cuenta_j1 (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .s_i(score1_pulso),
      .count_o(score1_total)
  );

  // Contador síncrono para el Jugador 2
  pulsecounter cuenta_j2 (
      .clk_i(clock25mhz),
      .rst_i(rst),
      .s_i(score2_pulso),
      .count_o(score2_total)
  );


  //4. INSTANCIACIÓN DEL MOTOR GRÁFICO (RENDER)
  render render_principal (
      .pixelx_i  (pixelx),        // Coordenada X del VGA
      .pixely_i  (pixely),        // Coordenada Y del VGA
      .ballx_i   (ball_x),        // Posición de la pelota
      .bally_i   (ball_y),
      .pad1y_i   (pad1_y),        // Posición raqueta izquierda
      .pad2y_i   (pad2_y),        // Posición raqueta derecha
      .score1_i  (score1_total),  // Puntuación actual J1
      .score2_i  (score2_total),  // Puntuación actual J2
      .video_on_i(video_on),      // 1 si es zona visible
      .r_o       (r),
      .g_o       (g),
      .b_o       (b)
  );


  //ETAPA DE REGENERACIÓN (Flip-Flops de salida contra Glitches)

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
  // Configuracion Modulo Bluethoot
  uart_rx uart0 (
      .i_clk(clk),
      .i_uart_rx(UART_RX),
      .o_wr(rx_ready),
      .o_data(rx_data)
  );
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      btn_up1   = 0;
      btn_up2   = 0;
      btn_down1 = 0;
      btn_down2 = 0;
      contador  = 20'd0;
    end

    if (rx_ready) begin
      case (rx_data)

        8'h57: btn_up1 <= 1;  // W

        8'h41: btn_up2 <= 1;  // A

        8'h53: btn_down1 <= 1;  // S

        8'h44: btn_down1 <= 1;  // D

      endcase
    end
    if (contador == Velocidad) begin
      btn_up1   <= 0;
      btn_up2   <= 0;
      btn_down1 <= 0;
      btn_down2 <= 0;
      contador  <= 20'd0;
    end else begin
      contador <= contador + 20'd1;
    end
  end


endmodule








