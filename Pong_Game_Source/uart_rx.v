// =============================================================================
// uart_rx.v — Receptor UART serie, 9600 baudios, 8N1, reloj de 50 MHz
//
// Formato 8N1:
//   - 1 bit de start (bajo)
//   - 8 bits de datos (LSB primero)
//   - 1 bit de stop (alto)
//   Sin bit de paridad.
//
// Puertos:
//   i_clk      — Reloj del sistema (50 MHz)
//   i_uart_rx  — Línea serie entrante (un solo bit)
//   o_wr       — Pulso de un ciclo: indica que o_data contiene un byte válido
//   o_data     — Byte recibido (8 bits)
// =============================================================================

module uart_rx(
    input  wire        i_clk,      // Reloj principal del sistema (50 MHz)
    input  wire        i_uart_rx,  // Pin de entrada serie UART (RX)
    output reg         o_wr,       // Strobe de escritura: 1 durante UN ciclo cuando el byte está listo
    output reg  [7:0]  o_data      // Dato recibido (8 bits, LSB primero según protocolo UART)
);

    // -------------------------------------------------------------------------
    // Parámetro de velocidad
    // Fórmula: CLOCKS_PER_BAUD = F_clk / Baudrate = 50_000_000 / 9600 ≈ 5208
    // Se declara como 'parameter' para poder cambiarlo desde fuera del módulo
    // si se desea otra velocidad o frecuencia de reloj.
    // -------------------------------------------------------------------------
    parameter [15:0] CLOCKS_PER_BAUD = 5208;

    // -------------------------------------------------------------------------
    // Estados de la máquina de estados finita (FSM)
    //
    // El protocolo UART tiene 10 bits en total:
    //   [start] [b0] [b1] [b2] [b3] [b4] [b5] [b6] [b7] [stop]
    //
    // La FSM usa el truco de state+1 para avanzar automáticamente entre
    // BIT_ZERO (1) y STOP_BIT (9) sin necesitar los localparam intermedios
    // (están comentados pero no son necesarios en el hardware).
    // -------------------------------------------------------------------------
    localparam [3:0] IDLE      = 4'h0; // Reposo: esperando el bit de start
    localparam [3:0] BIT_ZERO  = 4'h1; // Capturando bit 0 (LSB) del dato
    // Los estados 4'h2 a 4'h8 (BIT_ONE a BIT_SEVEN) se generan implícitamente
    // mediante la expresión "state <= state + 1" en la lógica de transición.
    // localparam [3:0] BIT_ONE   = 4'h2;
    // localparam [3:0] BIT_TWO   = 4'h3;
    // localparam [3:0] BIT_THREE = 4'h4;
    // localparam [3:0] BIT_FOUR  = 4'h5;
    // localparam [3:0] BIT_FIVE  = 4'h6;
    // localparam [3:0] BIT_SIX   = 4'h7;
    // localparam [3:0] BIT_SEVEN = 4'h8;
    localparam [3:0] STOP_BIT  = 4'h9; // Estado del bit de stop; activa o_wr al terminar

    // -------------------------------------------------------------------------
    // Registros internos
    // -------------------------------------------------------------------------
    reg [3:0]  state;             // Estado actual de la FSM
    reg [15:0] baud_counter;      // Contador regresivo: mide el tiempo de cada bit
    reg        zero_baud_counter; // Señal combinacional: 1 cuando baud_counter == 0

    // =========================================================================
    // SINCRONIZADOR DE DOS FLIP-FLOPS (2FF Synchronizer)
    //
    // La línea i_uart_rx viene del mundo exterior y puede cambiar en cualquier
    // momento, lo que puede causar METAESTABILIDAD si se muestrea directamente
    // (el flip-flop queda en un estado indeterminado entre 0 y 1).
    //
    // Solución estándar: pasar la señal por dos flip-flops en cascada.
    //   i_uart_rx → q_uart (1er FF) → ck_uart (2do FF)
    //
    // El primer flip-flop puede metaestabilizarse, pero tendrá un ciclo
    // entero de reloj para resolverse antes de que el segundo lo muestree.
    // ck_uart es la señal estable y sincronizada que usa el resto del módulo.
    //
    // La inicialización a -1 (todos los bits en 1) simula la línea UART en
    // reposo (UART idle = línea HIGH).
    // =========================================================================
    reg ck_uart; // Señal UART sincronizada y estable (segundo FF)
    reg q_uart;  // Etapa intermedia del sincronizador (primer FF)

    initial { ck_uart, q_uart } = -1; // Reposo = línea en alto (UART idle)

    always @(posedge i_clk)
        // En cada flanco de reloj: q_uart muestrea la entrada cruda,
        // ck_uart muestrea q_uart (ya estabilizado).
        { ck_uart, q_uart } <= { q_uart, i_uart_rx };

    // =========================================================================
    // MÁQUINA DE ESTADOS + CONTADOR DE BAUD
    //
    // Comportamiento general:
    //   1. En IDLE: espera que la línea baje a 0 (bit de start).
    //   2. Al detectar el start: carga 1.5× baudios en el contador.
    //      El objetivo es saltar el start bit y muestrear en el CENTRO
    //      de cada bit de dato (punto más lejos de las transiciones → más estable).
    //   3. Cada vez que el contador llega a 0: avanza al siguiente estado
    //      y recarga el contador con exactamente 1 baudio.
    //   4. Al llegar a STOP_BIT: vuelve a IDLE y pulsa o_wr.
    // =========================================================================
    initial state        = IDLE;
    initial baud_counter = 0;

    always @(posedge i_clk)
    if (state == IDLE)
    begin
        // En reposo: el contador no corre
        state        <= IDLE;
        baud_counter <= 0;

        if (!ck_uart) // Se detecta flanco descendente → bit de start recibido
        begin
            state <= BIT_ZERO;
            // Carga 1.5× baudios:
            //   - 1 baudio completo salta el start bit
            //   - 0.5 baudio adicional centra el muestreo en el bit 0
            // El -1 es porque el contador se evalúa en el ciclo siguiente.
            baud_counter <= CLOCKS_PER_BAUD + CLOCKS_PER_BAUD / 2 - 1'b1;
        end

    end else if (zero_baud_counter) // El contador llegó a 0: es hora de muestrear
    begin
        // Avanza al siguiente estado (BIT_ZERO→BIT_ONE→...→BIT_SEVEN→STOP_BIT)
        state        <= state + 1;
        // Recarga el contador para exactamente 1 baudio (muestreo del siguiente bit)
        baud_counter <= CLOCKS_PER_BAUD - 1'b1;

        if (state == STOP_BIT) // Fin de trama: se procesó el stop bit
        begin
            state        <= IDLE;   // Volver a esperar el próximo byte
            baud_counter <= 0;      // Detener el contador
        end

    end else
        // El contador no llegó a 0 todavía: simplemente decrementar
        baud_counter <= baud_counter - 1'b1;

    // =========================================================================
    // SEÑAL COMBINACIONAL: zero_baud_counter
    //
    // Se actualiza instantáneamente (bloque always @(*)) para que la FSM
    // de arriba pueda usarla en el mismo ciclo en que el contador llega a 0.
    // =========================================================================
    always @(*)
        zero_baud_counter = (baud_counter == 0);

    // =========================================================================
    // CAPTURA DE BITS DE DATO
    //
    // Cada vez que el contador llega a 0 Y no estamos en STOP_BIT,
    // se muestrea ck_uart y se inserta en o_data por la izquierda,
    // desplazando los bits previos hacia la derecha (shift register).
    //
    // UART envía LSB primero. Tras 8 capturas:
    //   - El primer bit capturado (bit 0) habrá sido desplazado a o_data[0]
    //   - El último (bit 7) quedará en o_data[7]
    // El orden queda correcto automáticamente gracias al desplazamiento.
    //
    // Ejemplo con dato 0xA5 (10100101):
    //   Captura 1: o_data = {1, xxxxxxx}  (b0=1)
    //   Captura 2: o_data = {0, 1xxxxxx}  (b1=0)
    //   ...
    //   Captura 8: o_data = {1, 0100101} = 10100101 = 0xA5 ✓
    // =========================================================================
    always @(posedge i_clk)
    if ((zero_baud_counter) && (state != STOP_BIT))
        // ck_uart entra por el MSB; los bits anteriores se desplazan a la derecha
        o_data <= { ck_uart, o_data[7:1] };

    // =========================================================================
    // SEÑAL DE DATO LISTO (o_wr)
    //
    // Se pone a 1 durante EXACTAMENTE UN ciclo de reloj cuando se detecta
    // el stop bit válido. Es el "write enable" que avisa al resto del sistema
    // que o_data contiene un byte completo y válido listo para consumir.
    // =========================================================================
    initial o_wr = 1'b0;

    always @(posedge i_clk)
        // 1 solo si el contador llegó a 0 Y estamos en el estado STOP_BIT
        o_wr <= ((zero_baud_counter) && (state == STOP_BIT));

endmodule
