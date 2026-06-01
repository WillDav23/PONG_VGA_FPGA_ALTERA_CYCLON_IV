module vga (

    input wire clk_i,
    input wire rst_i,
    output reg [9:0] pixely_o,
    pixelx_o,
    output wire hsync_o,
    vsync_o, video_on_o

);
  localparam integer EndLine = 10'd799;
  localparam integer EndFrame = 10'd524;

  localparam integer HsyncStart = 10'd656;
  localparam integer HsyncEnd = 10'd752;
  localparam integer VsyncStart = 10'd490;
  localparam integer VsyncEnd = 10'd492;

  always @(posedge clk_i or posedge rst_i) begin
    if (rst_i) begin
      //Inicializa las variables cuando se ejecuta un reset
      pixely_o <= 10'd0;
      pixelx_o <= 10'd0;
    end else begin
      //Realiza el contador
      if (pixelx_o == EndLine) begin
        pixelx_o <= 10'd0;
        if (pixely_o == EndFrame) begin
          pixely_o <= 10'd0;
        end else begin
          pixely_o <= pixely_o + 10'd1;
        end
      end else pixelx_o <= pixelx_o + 10'd1;
    end
  end

  //Por protocolo la señal es negativo cuando salta de linea o frame
  assign hsync_o = (pixelx_o >= HsyncStart && pixelx_o < HsyncEnd) ? 1'b0 : 1'b1;
  assign vsync_o = (pixely_o >= VsyncStart && pixely_o < VsyncEnd) ? 1'b0 : 1'b1;
  assign video_on_o   = (pixelx_o < 10'd640 && pixely_o < 10'd480) ? 1'b1 : 1'b0;
endmodule

