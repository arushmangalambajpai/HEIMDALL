`timescale 1ns/1ps

module wave_test;

reg clk = 0;

always #5 clk = ~clk;

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, wave_test);

    #100;

    $finish;
end

endmodule