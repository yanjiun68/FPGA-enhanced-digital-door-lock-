`timescale 1ns/1ps

module tb_custom_FPGA_door_lock;

    reg CLOCK_50;
    reg [17:0] SW;

    wire [8:0] LEDG;
    wire [17:0] LEDR;

    wire [6:0] HEX0;
    wire [6:0] HEX1;
    wire [6:0] HEX2;
    wire [6:0] HEX3;
    wire [6:0] HEX4;
    wire [6:0] HEX5;
    wire [6:0] HEX6;
    wire [6:0] HEX7;

    integer pass_count;
    integer fail_count;

    localparam integer CLK_FREQ_HZ = 10;
    localparam integer LOCK_DELAY_SEC = 5;
    localparam integer MAX_FAILED_ATTEMPTS = 5;

    localparam integer LOCK_DELAY_CYCLES = CLK_FREQ_HZ * LOCK_DELAY_SEC;
    localparam integer BLINK_HALF_CYCLES = CLK_FREQ_HZ / 2;

    custom_FPGA_door_lock #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .LOCK_DELAY_SEC(LOCK_DELAY_SEC),
        .MAX_FAILED_ATTEMPTS(MAX_FAILED_ATTEMPTS)
    ) dut (
        .CLOCK_50(CLOCK_50),
        .SW(SW),
        .LEDG(LEDG),
        .LEDR(LEDR),
        .HEX0(HEX0),
        .HEX1(HEX1),
        .HEX2(HEX2),
        .HEX3(HEX3),
        .HEX4(HEX4),
        .HEX5(HEX5),
        .HEX6(HEX6),
        .HEX7(HEX7)
    );

    initial begin
        CLOCK_50 = 1'b0;
        forever #5 CLOCK_50 = ~CLOCK_50;
    end

    task wait_cycles;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge CLOCK_50);
            end
            #1;
        end
    endtask

    task check_result;
        input [255:0] test_name;
        input condition;
        begin
            if (condition) begin
                $display("PASS: %s", test_name);
                pass_count = pass_count + 1;
            end
            else begin
                $display("FAIL: %s", test_name);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task set_password;
        input [9:0] password;
        begin
            SW = 18'b0;
            wait_cycles(1);

            SW[11] = 1'b1;
            SW[12] = 1'b1;
            SW[9:0] = password;
            wait_cycles(1);

            SW[17] = 1'b1;
            wait_cycles(1);

            SW[17] = 1'b0;
            wait_cycles(1);

            SW[11] = 1'b0;
            SW[12] = 1'b0;
            wait_cycles(1);
        end
    endtask

    task verify_password;
        input [9:0] password;
        begin
            SW[16] = 1'b0;
            SW[9:0] = password;
            wait_cycles(1);

            SW[16] = 1'b1;
            wait_cycles(1);

            SW[16] = 1'b0;
            wait_cycles(1);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        SW = 18'b0;

        $display("========================================");
        $display("Starting Door Lock Testbench");
        $display("========================================");

        wait_cycles(2);

        check_result(
            "Initial state should have all LEDs OFF",
            LEDG == 9'b000000000 && LEDR == 18'b000000000000000000
        );

        set_password(10'b1010101010);

        check_result(
            "Password set/reset mode should return to IDLE with LEDs OFF",
            LEDG == 9'b000000000 && LEDR == 18'b000000000000000000
        );

        verify_password(10'b1010101010);

        check_result(
            "Correct password should unlock green LEDs",
            LEDG == 9'b111111111 && LEDR == 18'b000000000000000000
        );

        verify_password(10'b0000000001);

        check_result(
            "First wrong password should turn ON red LEDs",
            LEDG == 9'b000000000 && LEDR == 18'b111111111111111111
        );

        wait_cycles(LOCK_DELAY_CYCLES + 2);

        check_result(
            "After lock delay, system should return to IDLE with LEDs OFF",
            LEDG == 9'b000000000 && LEDR == 18'b000000000000000000
        );

        verify_password(10'b0000000010);
        wait_cycles(LOCK_DELAY_CYCLES + 2);

        verify_password(10'b0000000011);
        wait_cycles(LOCK_DELAY_CYCLES + 2);

        verify_password(10'b0000000100);
        wait_cycles(LOCK_DELAY_CYCLES + 2);

        verify_password(10'b0000000101);

        check_result(
            "Fifth wrong password should enter LOCKDOWN with red LEDs initially ON",
            LEDG == 9'b000000000 && LEDR == 18'b111111111111111111
        );

        wait_cycles(BLINK_HALF_CYCLES + 1);

        check_result(
            "During LOCKDOWN, red LEDs should flicker OFF after 0.5 seconds",
            LEDR == 18'b000000000000000000
        );

        wait_cycles(BLINK_HALF_CYCLES);

        check_result(
            "During LOCKDOWN, red LEDs should flicker ON again after another 0.5 seconds",
            LEDR == 18'b111111111111111111
        );

        verify_password(10'b1010101010);

        check_result(
            "Correct password should not unlock during LOCKDOWN",
            LEDG == 9'b000000000
        );

        set_password(10'b1111100000);

        check_result(
            "Reset mode with SW17 should clear LOCKDOWN and return to IDLE",
            LEDG == 9'b000000000 && LEDR == 18'b000000000000000000
        );

        verify_password(10'b1111100000);

        check_result(
            "New password should unlock after reset",
            LEDG == 9'b111111111 && LEDR == 18'b000000000000000000
        );

        $display("========================================");
        $display("Testbench Completed");
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        $display("========================================");

        if (fail_count == 0) begin
            $display("ALL TESTS PASSED");
        end
        else begin
            $display("SOME TESTS FAILED");
        end

        $stop;
    end

endmodule