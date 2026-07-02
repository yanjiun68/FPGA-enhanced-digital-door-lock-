# FPGA Based Digital Smart Door Lock

## Project Overview

This project implements a digital smart door lock using Verilog HDL for an FPGA development board such as the DE2-115. The main focus of the design is the lockdown security layer mechanism, which demonstrates practical digital system logic concepts such as finite state machines, edge detection, counters, timers, password comparison, and output control.

The system uses FPGA switches as password and control inputs, green LEDs to indicate successful unlock, red LEDs to indicate lock or lockdown conditions, and seven-segment displays to show the current lock status.

## Key Features

- 10-bit password input using `SW[9:0]`
- Password verification using rising edge detection on `SW[16]`
- Password reset/set mode using `SW[11]` and `SW[12]`
- Password update using rising edge detection on `SW[17]`
- Failed attempt counter
- Temporary lock delay after a wrong password
- Permanent lockdown after maximum failed attempts
- Red LED flickering every 0.5 seconds during lockdown
- Seven-segment display status output

## Main Input Controls

| Signal | Function |
|---|---|
| `CLOCK_50` | 50 MHz FPGA clock |
| `SW[9:0]` | 10-bit password input |
| `SW[11]` | Reset mode control bit 1 |
| `SW[12]` | Reset mode control bit 2 |
| `SW[16]` | Verify password trigger |
| `SW[17]` | Set/reset password trigger |

`reset_mode = SW[11] & SW[12]`

## Finite State Machine Diagram

```mermaid
stateDiagram-v2
    [*] --> IDLE

    IDLE --> UNLOCKED: SW16 rising edge\nPassword correct
    IDLE --> LOCKED: SW16 rising edge\nPassword wrong\nFailed attempts < max - 1
    IDLE --> LOCKDOWN: SW16 rising edge\nPassword wrong\nFailed attempts = max - 1

    LOCKED --> IDLE: Lock delay timer expires

    UNLOCKED --> UNLOCKED: SW16 rising edge\nPassword correct
    UNLOCKED --> LOCKED: SW16 rising edge\nPassword wrong\nFailed attempts < max - 1
    UNLOCKED --> LOCKDOWN: SW16 rising edge\nPassword wrong\nFailed attempts = max - 1

    LOCKDOWN --> LOCKDOWN: Red LEDs blink every 0.5s
    LOCKDOWN --> IDLE: Reset mode active\nSW17 rising edge

    IDLE --> IDLE: Reset mode active\nSW17 rising edge\nSave new password
    LOCKED --> IDLE: Reset mode active\nSW17 rising edge\nSave new password
    UNLOCKED --> IDLE: Reset mode active\nSW17 rising edge\nSave new password
```

## Functional Behavior Table

| Case | Current Condition | Input Action | Password Match? | Internal Action | Expected LED Output | Expected HEX Output |
|---|---|---|---|---|---|---|
| 1 | Power-on / idle state | No verify trigger | Not checked | Wait for user input | `LEDG = 0`, `LEDR = 0` | Blank |
| 2 | Reset mode active | `SW[11]=1`, `SW[12]=1` | Not checked | Show reset mode; timers cleared | `LEDG = 0`, `LEDR = 0` | `RESET` |
| 3 | Reset mode active | `SW17` rising edge | Not checked | Save `SW[9:0]` as new password; clear failed attempts; return to `IDLE` | `LEDG = 0`, `LEDR = 0` | `RESET` while reset mode remains active |
| 4 | `IDLE` | `SW16` rising edge | Yes | Set state to `UNLOCKED`; clear failed attempts | `LEDG = all ON`, `LEDR = all OFF` | `UNLOCKED` |
| 5 | `IDLE` | `SW16` rising edge | No | Increase failed attempts; enter `LOCKED`; start lock delay timer | `LEDG = all OFF`, `LEDR = all ON` | `LOCKED` |
| 6 | `LOCKED` | During lock delay | Ignored | Countdown timer active | `LEDG = all OFF`, `LEDR = all ON` | `LOCKED` |
| 7 | `LOCKED` | Lock delay expires | Not checked | Return to `IDLE` if not in lockdown | `LEDG = all OFF`, `LEDR = all OFF` | Blank |
| 8 | Any non-lockdown state | Wrong password reaches maximum failed attempts | No | Enter `LOCKDOWN`; stop normal lock timer | `LEDG = all OFF`, `LEDR = blinking all ON/OFF every 0.5s` | `LOCKED` |
| 9 | `LOCKDOWN` | `SW16` rising edge | Ignored | Stay in lockdown | `LEDG = all OFF`, `LEDR = blinking all ON/OFF every 0.5s` | `LOCKED` |
| 10 | `LOCKDOWN` | Reset mode active only | Not checked | Show reset mode externally, but internal state remains unless `SW17` rises | `LEDG = 0`, `LEDR = 0` | `RESET` |
| 11 | `LOCKDOWN` + reset mode active | `SW17` rising edge | Not checked | Save new password; clear failed attempts; return to `IDLE` | `LEDG = 0`, `LEDR = 0` | `RESET` while reset mode remains active |
| 12 | `UNLOCKED` | `SW16` rising edge | Yes | Stay `UNLOCKED`; failed attempts remain cleared | `LEDG = all ON`, `LEDR = all OFF` | `UNLOCKED` |
| 13 | `UNLOCKED` | `SW16` rising edge | No | Increase failed attempts; enter `LOCKED` or `LOCKDOWN` depending on counter | `LEDG = all OFF`, `LEDR = all ON` or blinking | `LOCKED` |

## State Output Summary

| State | Meaning | Green LEDs | Red LEDs | Seven-Segment Display |
|---|---|---|---|---|
| `IDLE` | Waiting for password verification | OFF | OFF | Blank |
| `UNLOCKED` | Correct password entered | ON | OFF | `UNLOCKED` |
| `LOCKED` | Wrong password entered; temporary lock delay active | OFF | ON | `LOCKED` |
| `LOCKDOWN` | Maximum failed attempts reached | OFF | Flickers every 0.5 seconds | `LOCKED` |
| Reset mode | Password set/reset mode | OFF | OFF | `RESET` |

## Timing Parameters

| Parameter | Default Value | Purpose |
|---|---:|---|
| `CLK_FREQ_HZ` | `50000000` | FPGA clock frequency |
| `LOCK_DELAY_SEC` | `5` | Delay time after wrong password attempt |
| `MAX_FAILED_ATTEMPTS` | `5` | Number of failed attempts before lockdown |
| `BLINK_HALF_CYCLES` | `CLK_FREQ_HZ / 2` | Controls 0.5-second LED flicker interval |


```


