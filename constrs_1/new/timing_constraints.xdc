# 定义一个名为sys_clk，周期为5ns的时钟，并将其关联到名为clk的顶层端口
create_clock -period 5.0 -name sys_clk [get_ports clk]