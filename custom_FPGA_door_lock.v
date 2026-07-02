module custom_FPGA_door_lock #(
    parameter integer CLK_FREQ_HZ = 50000000,
    parameter integer LOCK_DELAY_SEC = 5,
    parameter integer MAX_FAILED_ATTEMPTS = 5
) (
    input CLOCK_50,          // DE2-115 50 MHz clock
    input [17:0] SW,         // SW[9:0] password, SW11+SW12 reset mode, SW16 verify, SW17 reset/set

    output reg [8:0] LEDG,   // Green LEDs
    output reg [17:0] LEDR,  // Red LEDs

    output reg [6:0] HEX0,
    output reg [6:0] HEX1,
    output reg [6:0] HEX2,
    output reg [6:0] HEX3,
    output reg [6:0] HEX4,
    output reg [6:0] HEX5,
    output reg [6:0] HEX6,
    output reg [6:0] HEX7
);

    localparam [2:0] IDLE     = 3'b000;
    localparam [2:0] UNLOCKED = 3'b001;
    localparam [2:0] LOCKED   = 3'b010;
    localparam [2:0] LOCKDOWN = 3'b011;

    localparam integer LOCK_DELAY_CYCLES = CLK_FREQ_HZ * LOCK_DELAY_SEC;
    localparam integer BLINK_HALF_CYCLES = CLK_FREQ_HZ / 2;

    reg [9:0] saved_password = 10'b0000000000;
    reg [2:0] lock_status = IDLE;
    reg [2:0] failed_attempts = 3'd0;
    reg [31:0] lock_timer = 32'd0;
    reg timer_active = 1'b0;

    reg [31:0] blink_timer = 32'd0;
    reg blink_state = 1'b1;

    reg sw16_prev = 1'b0;
    reg sw17_prev = 1'b0;

    wire sw16_rising;
    wire sw17_rising;
    wire reset_mode;

    assign sw16_rising = SW[16] & ~sw16_prev;
    assign sw17_rising = SW[17] & ~sw17_prev;
    assign reset_mode = SW[11] & SW[12];

    always @(posedge CLOCK_50) begin
        sw16_prev <= SW[16];
        sw17_prev <= SW[17];

        if (reset_mode == 1'b1) begin
            timer_active <= 1'b0;
            lock_timer <= 32'd0;
            blink_timer <= 32'd0;
            blink_state <= 1'b1;

            if (sw17_rising == 1'b1) begin
                saved_password <= SW[9:0];
                failed_attempts <= 3'd0;
                lock_status <= IDLE;
            end
        end
        else begin
            if (lock_status == LOCKDOWN) begin
                if (blink_timer >= BLINK_HALF_CYCLES - 1) begin
                    blink_timer <= 32'd0;
                    blink_state <= ~blink_state;
                end
                else begin
                    blink_timer <= blink_timer + 32'd1;
                end
            end
            else begin
                blink_timer <= 32'd0;
                blink_state <= 1'b1;
            end

            if (timer_active == 1'b1) begin
                if (lock_timer > 32'd1) begin
                    lock_timer <= lock_timer - 32'd1;
                end
                else begin
                    lock_timer <= 32'd0;
                    timer_active <= 1'b0;

                    if (lock_status != LOCKDOWN) begin
                        lock_status <= IDLE;
                    end
                end
            end
            else if (lock_status != LOCKDOWN && sw16_rising == 1'b1) begin
                if (SW[9:0] == saved_password) begin
                    lock_status <= UNLOCKED;
                    failed_attempts <= 3'd0;
                end
                else begin
                    if (failed_attempts == MAX_FAILED_ATTEMPTS - 1) begin
                        failed_attempts <= failed_attempts + 3'd1;
                        lock_status <= LOCKDOWN;
                        timer_active <= 1'b0;
                        lock_timer <= 32'd0;
                    end
                    else begin
                        failed_attempts <= failed_attempts + 3'd1;
                        lock_status <= LOCKED;
                        timer_active <= 1'b1;
                        lock_timer <= LOCK_DELAY_CYCLES;
                    end
                end
            end
        end
    end

    always @(*) begin
        LEDG = 9'b000000000;
        LEDR = 18'b000000000000000000;

        if (reset_mode == 1'b1) begin
            LEDG = 9'b000000000;
            LEDR = 18'b000000000000000000;
        end
        else begin
            case (lock_status)
                UNLOCKED: begin
                    LEDG = 9'b111111111;
                    LEDR = 18'b000000000000000000;
                end

                LOCKED: begin
                    LEDG = 9'b000000000;
                    LEDR = 18'b111111111111111111;
                end

                LOCKDOWN: begin
                    LEDG = 9'b000000000;
                    LEDR = blink_state ? 18'b111111111111111111 :
                                         18'b000000000000000000;
                end

                default: begin
                    LEDG = 9'b000000000;
                    LEDR = 18'b000000000000000000;
                end
            endcase
        end
    end

    always @(*) begin
        if (reset_mode == 1'b1) begin
            HEX7 = seg7_char(" ");
            HEX6 = seg7_char(" ");
            HEX5 = seg7_char(" ");
            HEX4 = seg7_char("R");
            HEX3 = seg7_char("E");
            HEX2 = seg7_char("S");
            HEX1 = seg7_char("E");
            HEX0 = seg7_char("T");
        end
        else begin
            case (lock_status)
                UNLOCKED: begin
                    HEX7 = seg7_char("U");
                    HEX6 = seg7_char("N");
                    HEX5 = seg7_char("L");
                    HEX4 = seg7_char("O");
                    HEX3 = seg7_char("C");
                    HEX2 = seg7_char("K");
                    HEX1 = seg7_char("E");
                    HEX0 = seg7_char("D");
                end

                LOCKED, LOCKDOWN: begin
                    HEX7 = seg7_char(" ");
                    HEX6 = seg7_char(" ");
                    HEX5 = seg7_char("L");
                    HEX4 = seg7_char("O");
                    HEX3 = seg7_char("C");
                    HEX2 = seg7_char("K");
                    HEX1 = seg7_char("E");
                    HEX0 = seg7_char("D");
                end

                default: begin
                    HEX7 = seg7_char(" ");
                    HEX6 = seg7_char(" ");
                    HEX5 = seg7_char(" ");
                    HEX4 = seg7_char(" ");
                    HEX3 = seg7_char(" ");
                    HEX2 = seg7_char(" ");
                    HEX1 = seg7_char(" ");
                    HEX0 = seg7_char(" ");
                end
            endcase
        end
    end

    function [6:0] seg7_char;
        input [7:0] ch;
        begin
            case (ch)
                "U": seg7_char = 7'b1000001;
                "N": seg7_char = 7'b1101010;
                "L": seg7_char = 7'b1000111;
                "O": seg7_char = 7'b1000000;
                "C": seg7_char = 7'b1000110;
                "K": seg7_char = 7'b1001000;
                "E": seg7_char = 7'b0000110;
                "D": seg7_char = 7'b0100001;
                "R": seg7_char = 7'b0101111;
                "S": seg7_char = 7'b0010010;
                "T": seg7_char = 7'b0000111;
                " ": seg7_char = 7'b1111111;
                default: seg7_char = 7'b1111111;
            endcase
        end
    endfunction

endmodule