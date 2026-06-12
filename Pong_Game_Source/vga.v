// =============================================================================
// vga.v — Generador de señales VGA 640×480 @ 60 Hz
//
// Implementa el timing estándar VESA para VGA:
//   Resolución visible : 640 × 480 píxeles
//   Frecuencia de frame: 60 Hz
//   Frecuencia de línea: 31.469 kHz
//   Frecuencia de píxel: 25.175 MHz (usar PLL en la FPGA)
//
// Estructura de una línea horizontal (800 clocks totales):
//   [0–639]   640 clocks — zona activa (píxeles visibles)
//   [640–655]  16 clocks — front porch (blanking antes del sync)
//   [656–751]  96 clocks — pulso HSYNC (activo en BAJO)
//   [752–799]  48 clocks — back porch  (blanking después del sync)
//
// Estructura de un frame vertical (525 líneas totales):
//   [0–479]   480 líneas — zona activa (filas visibles)
//   [480–489]  10 líneas — front porch
//   [490–491]   2 líneas — pulso VSYNC (activo en BAJO)
//   [492–524]  33 líneas — back porch
//
// Puertos:
//   clk_i      — Reloj de píxel (idealmente 25.175 MHz vía PLL)
//   rst_i      — Reset asíncrono activo en alto
//   pixelx_o   — Posición horizontal actual del "haz" (0 a 799)
//   pixely_o   — Posición vertical actual del "haz" (0 a 524)
//   hsync_o    — Pulso de sincronismo horizontal (activo en BAJO)
//   vsync_o    — Pulso de sincronismo vertical   (activo en BAJO)
//   video_on_o — 1 cuando el haz está en la zona visible (usar para habilitar color)
// =============================================================================

module vga (
    input  wire        clk_i,      // Reloj de píxel (~25 MHz desde PLL)
    input  wire        rst_i,      // Reset asíncrono activo en alto
    output reg  [9:0]  pixely_o,   // Coordenada Y actual (fila), 0–524
    output reg  [9:0]  pixelx_o,   // Coordenada X actual (columna), 0–799
    output wire        hsync_o,    // Sincronismo horizontal (activo LOW)
    output wire        vsync_o,    // Sincronismo vertical   (activo LOW)
    output wire        video_on_o  // Habilitador de video: 1 solo en zona visible
);

    // -------------------------------------------------------------------------
    // Constantes de timing VESA VGA 640×480 @ 60 Hz
    //
    // Los valores están expresados en número de clocks (para H) o líneas (para V).
    // "End" indica el último valor del contador antes de reiniciar.
    // "Start/End" de sync indican el rango donde la señal está activa (en bajo).
    // -------------------------------------------------------------------------

    // Fin del contador horizontal: 800 posiciones → 0..799
    localparam integer EndLine    = 10'd799;

    // Fin del contador vertical: 525 líneas → 0..524
    localparam integer EndFrame   = 10'd524;

    // HSYNC: activo (LOW) desde el clock 656 hasta el 751 inclusive
    // La condición del assign usa ">= Start && < End", por eso End = 752 (exclusivo)
    localparam integer HsyncStart = 10'd656;
    localparam integer HsyncEnd   = 10'd752; // El último clock activo es el 751

    // VSYNC: activo (LOW) en las líneas 490 y 491 (solo 2 líneas de duración)
    localparam integer VsyncStart = 10'd490;
    localparam integer VsyncEnd   = 10'd492; // La última línea activa es la 491

    // =========================================================================
    // CONTADORES DE POSICIÓN (raster scan)
    //
    // pixelx_o: contador horizontal, avanza un paso por cada ciclo de reloj.
    //   Al llegar a EndLine (799), se reinicia y avanza pixely_o.
    //
    // pixely_o: contador vertical, avanza una línea cada vez que pixelx_o
    //   completa una línea completa. Al llegar a EndFrame (524), se reinicia
    //   comenzando un nuevo frame.
    //
    // El par (pixelx_o, pixely_o) recorre todas las posiciones del raster
    // de izquierda a derecha y de arriba a abajo, 60 veces por segundo.
    //
    // Reset asíncrono: si rst_i sube en cualquier momento, ambos contadores
    // vuelven a (0,0) inmediatamente, sin esperar al flanco de reloj.
    // =========================================================================
    always @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // Reset: el cursor vuelve a la esquina superior izquierda
            pixely_o <= 10'd0;
            pixelx_o <= 10'd0;
        end else begin

            if (pixelx_o == EndLine) begin
                // Fin de línea horizontal: reiniciar X y avanzar Y
                pixelx_o <= 10'd0;

                if (pixely_o == EndFrame) begin
                    // Fin de frame completo: reiniciar también Y (nuevo frame)
                    pixely_o <= 10'd0;
                end else begin
                    // Pasar a la siguiente línea
                    pixely_o <= pixely_o + 10'd1;
                end

            end else begin
                // Avanzar al siguiente píxel en la misma línea
                pixelx_o <= pixelx_o + 10'd1;
            end

        end
    end

    // =========================================================================
    // SEÑAL HSYNC — Sincronismo horizontal (activo en BAJO)
    //
    // Según el estándar VGA la señal debe ser LOW durante el pulso de sync.
    // El operador ternario implementa la lógica:
    //   Si pixelx_o está dentro del rango [HsyncStart, HsyncEnd) → salida = 0
    //   En cualquier otro momento                                  → salida = 1
    //
    // Es una señal puramente combinacional (assign), sin latencia de flip-flop.
    // Esto es importante para que el timing sea exacto al ciclo.
    // =========================================================================
    assign hsync_o = (pixelx_o >= HsyncStart && pixelx_o < HsyncEnd) ? 1'b0 : 1'b1;

    // =========================================================================
    // SEÑAL VSYNC — Sincronismo vertical (activo en BAJO)
    //
    // Misma lógica que HSYNC pero para la dimensión vertical.
    // El pulso dura solo 2 líneas (490 y 491) porque cada línea ya representa
    // ~32 µs — dos líneas son suficientes para que el monitor sincronice.
    // =========================================================================
    assign vsync_o = (pixely_o >= VsyncStart && pixely_o < VsyncEnd) ? 1'b0 : 1'b1;

    // =========================================================================
    // SEÑAL VIDEO_ON — Habilitador de zona visible
    //
    // Vale 1 únicamente cuando el "haz" está dentro de los 640×480 píxeles
    // visibles. El módulo que genera color (pong.v, sprites, etc.) debe usar
    // esta señal así:
    //
    //   assign color_r = video_on_o ? r_calculado : 4'b0000;
    //   assign color_g = video_on_o ? g_calculado : 4'b0000;
    //   assign color_b = video_on_o ? b_calculado : 4'b0000;
    //
    // Durante el blanking (video_on_o = 0) los cables de color DEBEN estar
    // en 0. Si hubiera señal de color durante el sync o los porches, el
    // monitor podría mostrar artefactos o no sincronizar correctamente.
    // =========================================================================
    assign video_on_o = (pixelx_o < 10'd640 && pixely_o < 10'd480) ? 1'b1 : 1'b0;

endmodule
