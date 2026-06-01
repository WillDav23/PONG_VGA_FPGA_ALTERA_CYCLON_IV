module pll25mhz (
    input  wire clk_50mhz_i, // Reloj físico de entrada (50 MHz)
    output wire clk_25mhz_o  // Reloj de píxel de salida (25 MHz)
);

    altpll #(
        .intended_device_family ("Cyclone IV E"),
        .inclk0_input_frequency (20000),  // Período de la entrada: 1 / 50 MHz = 20,000 ps
        .clk0_multiply_by       (1),      // Multiplicador
        .clk0_divide_by         (2),      // Divisor → 50 MHz × 1 / 2 = 25 MHz
        .clk0_duty_cycle        (50),
        .operation_mode         ("NORMAL"),
        .compensate_clock       ("CLK0")
    ) altpll_inst (
        .inclk  ({1'b0, clk_50mhz_i}),   // Conexión del reloj de entrada
        .clk    (clk_25mhz_o)            // Conexión del reloj de salida
    );

endmodule
