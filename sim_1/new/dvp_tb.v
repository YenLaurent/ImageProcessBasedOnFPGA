`timescale 1ns / 1ps
module dvp_tb();
reg rst_p;
reg pclk;
reg vsync;
reg href;
reg [7:0] data;

wire imagestate;
wire datavalid;
wire [15:0] datapixel;
wire datahs;
wire datavs;
wire [11:0] xaddr;
wire [11:0] yaddr;

DVP_Capture DVP_Capture(
  .Rst_p(rst_p),
  .PCLK(pclk),
  .Vsync(vsync),
  .Href(href),
  .Data(data),

  .ImageState(imagestate),
  .DataValid(datavalid),
  .DataPixel(datapixel),
  .DataHs(datahs),
  .DataVs(datavs),
  .Xaddr(xaddr),
  .Yaddr(yaddr)
); 

initial pclk = 1;
always #40 pclk=~pclk;

parameter width = 16;
parameter hight = 12;

integer i,j;

initial begin
    rst_p = 1;
    vsync = 0;
    href = 0;
    data = 8'h00;
    #805;
    rst_p=0;
    #400;
    
    repeat(15) begin
        vsync = 1;
        #320;
        vsync = 0;
        #800;
        for (i=0;i<hight;i=i+1)
        begin
            for (j=0;j<width;j=j+1)
            begin
                href =1;
                data = data -1;
                #80;
            end
            href = 0;
            #800;
        end
    end
end
endmodule
