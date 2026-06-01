// filename: top_tb.v
// brief: Testbench Pong - Reloj FPGA: 50 MHz | UART: 9600 Baudios
`timescale 1ns / 1ns

module top_tb;

  // 1. SEÑALES DEL TESTBENCH
  reg clk = 0;
  reg rst;
  reg UART_RX;

  wire hsync_o;
  wire vsync_o;
  wire clk_o;
  wire r_o;
  wire g_o;
  wire b_o;

  // REGLAS DE TIEMPO (50 MHz -> Periodo = 20 ns -> Semiperiodo = 10 ns)
  localparam CLK_PERIOD = 20;
  always #(CLK_PERIOD / 2) clk = !clk;

  // TIEMPO DE BIT UART (1s / 9600 baudios = 104,166 ns)
  localparam BIT_PERIOD_UART = 104166;

  // 2. INSTANCIACIÓN DEL DISEÑO BAJO PRUEBA (DUT)
  top dut (
      .clk    (clk),
      .rst    (rst),
      .UART_RX(UART_RX),
      .hsync_o(hsync_o),
      .vsync_o(vsync_o),
      .clk_o  (clk_o),
      .r_o    (r_o),
      .g_o    (g_o),
      .b_o    (b_o)
  );

  // 3. ARCHIVOS VCD PARA GTKWAVE
  initial begin
    $dumpfile("top_tb.vcd");
    $dumpvars(0, top_tb);
  end

  // 4. SECUENCIA DE ESTÍMULOS (Configuración del tiempo de simulación)
  initial begin
    // Estado inicial
    rst = 1;
    UART_RX = 1; // Línea en reposo (idle)
    
    // Mantener reset por 200 ns
    #(CLK_PERIOD * 10);
    rst = 0;
    #(CLK_PERIOD * 5);

    $display("[TB] Reset liberado. Iniciando transmisión UART a 9600 baudios...");

    // --- ENVIAR 'W' (8'h57) -> Mover raqueta 1 arriba
    // Cada byte tarda aprox. 1.04 ms en transmitirse completamente
    $display("[TB] Enviando 'W'...");
    enviar_byte_uart(8'h57); 
    #(CLK_PERIOD * 500); // Pequeña espera entre caracteres

    // --- ENVIAR 'D' (8'h44) -> Mover raqueta 2 abajo
    $display("[TB] Enviando 'D'...");
    enviar_byte_uart(8'h44);
    #(CLK_PERIOD * 500);

    // --- ENVIAR CARÁCTER REPOSO (8'h00) -> Apagar botones
    $display("[TB] Enviando caracter nulo...");
    enviar_byte_uart(8'h00);

    // --- TIEMPO FINAL DE SIMULACIÓN
    // Modifica este valor para darle más o menos tiempo a la simulación.
    // 12,000,000 ns = 12 milisegundos. Es suficiente para ver las 3 tramas UART 
    // completas y aproximadamente el 70% de un frame de video VGA (que dura 16.6 ms).
    $display("[TB] Dejando correr la simulación para capturar señales de video...");
    #12000000; 

    $display("[TB] Simulación terminada correctamente.");
    $finish;
  end

  // 5. TAREA PARA ENVIAR PROTOCOLO UART RS-232 REAL
  task enviar_byte_uart;
    input [7:0] data;
    integer i;
    begin
      // Bit de inicio (Start bit = 0)
      UART_RX = 0;
      #(BIT_PERIOD_UART);

      // 8 Bits de datos (LSB primero)
      for (i = 0; i < 8; i = i + 1) begin
        UART_RX = data[i];
        #(BIT_PERIOD_UART);
      end

      // Bit de parada (Stop bit = 1)
      UART_RX = 1;
      #(BIT_PERIOD_UART);
    end
  endtask

endmodule
