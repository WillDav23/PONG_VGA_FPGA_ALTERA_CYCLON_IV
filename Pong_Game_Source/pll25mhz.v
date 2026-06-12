// =====================================================================
// Módulo: pll25mhz
// Función: Generar el reloj de píxel de 25 MHz a partir del reloj
// físico de 50 MHz que entrega el oscilador de la placa.
//
// Tiene DOS implementaciones según el contexto de uso:
//  - SIMULATION: un divisor de frecuencia simple (flip-flop tipo toggle)
//  - SÍNTESIS REAL (Quartus): el bloque IP "altpll" de Altera/Intel
// =====================================================================

`define SIMULATION  // Activa la rama de simulación (toggle flip-flop)

module pll25mhz (
    input  wire clk_50mhz_i,  // Entrada: reloj físico del oscilador (50 MHz)
    output wire clk_25mhz_o   // Salida: reloj de píxel (25 MHz)
);

`ifdef SIMULATION
    // ------------------------------------------------------------
    // RAMA DE SIMULACIÓN
    // Como 25 MHz = 50 MHz / 2, basta con un flip-flop que invierta
    // su propio valor (toggle) en cada flanco de subida del reloj
    // de 50 MHz. Así, la salida cambia de estado cada ciclo de 50MHz,
    // es decir, completa un periodo completo cada 2 ciclos
    // -> frecuencia resultante = frecuencia de entrada / 2.
    // ------------------------------------------------------------
    reg r_c0 = 0;  // Registro que se invierte cada flanco de reloj

    always @(posedge clk_50mhz_i) begin
        r_c0 <= ~r_c0;  // Toggle: 0 -> 1 -> 0 -> 1 ...
    end

    assign clk_25mhz_o = r_c0;  // La salida es directamente ese registro

`else
    // ------------------------------------------------------------
    // RAMA DE SÍNTESIS REAL (Quartus / Cyclone IV)
    // Se usa el bloque IP dedicado "altpll", que aprovecha el
    // hardware analógico de PLL de la FPGA (no consume celdas
    // lógicas programables, a diferencia del divisor por software).
    // ------------------------------------------------------------
    altpll #(
        .intended_device_family ("Cyclone IV E"), // Familia de FPGA objetivo
        .inclk0_input_frequency (20000),  // Periodo de entrada en ps: 1/50MHz = 20000 ps
        .clk0_multiply_by       (1),      // Multiplicador del PLL
        .clk0_divide_by         (2),      // Divisor: 50MHz * 1 / 2 = 25MHz
        .clk0_duty_cycle        (50),     // Ciclo de trabajo simétrico (50%)
        .operation_mode         ("NORMAL"), // Modo de operación estándar
        .compensate_clock       ("CLK0")  // Reloj que el PLL compensa en fase
    ) altpll_inst (
        .inclk  ({1'b0, clk_50mhz_i}),  // Vector de entradas de reloj (solo usa inclk[0])
        .clk    (clk_25mhz_o)           // Salida del PLL: reloj de 25MHz
    );
`endif

endmodule
