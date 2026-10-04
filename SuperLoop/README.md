# SuperLoop: Python first, then FreeRTOS

This project is built to teach one idea clearly:

- A superloop can feel fine at first.
- One long write or blocking call makes the whole system feel laggy.
- A scheduler fixes that by letting other work run.
- An interrupt makes the system feel responsive because the timing is no longer tied to a single loop.

This project focuses on two main versions:

- `python/` — the classic superloop in MicroPython
- `freertos/` — the same behavior broken into tasks and scheduled by FreeRTOS

The C++ version is still here only as a comfort reference when you want to compare native C++ with the Python and RTOS versions. It is not the main teaching path.

## The story for class

Start with the Python version.

The whole program runs in one `while True` loop. It blinks LEDs, reads the potentiometer, moves the servo, updates the LCD, and writes a long message out the UART. That final UART write is the key demonstration. It blocks the loop long enough that the LEDs freeze and the system stops responding for a noticeable period.

That is the exact problem we want students to see: one slow action is stalling the whole system.

Then move to the FreeRTOS version.

The same work is now split into tasks. The LED pattern still runs, but it is no longer trapped in a huge blocking UART write. The scheduler lets other tasks get CPU time. The system feels responsive because the task that is busy is no longer the only thing in control.

Finally, explain the interrupt idea.

The scheduler is driven by a hardware tick interrupt. That tick is what keeps the system moving and makes `vTaskDelay()` meaningful. The loop is no longer the only clock in the system.

## Wiring

All variants use the same pins.

| Signal | Pico GPIO | Notes |
| --- | --- | --- |
| Red LED | 3 | |
| Yellow LED | 2 | |
| Green LED | 0 | |
| Potentiometer | 26 | ADC0 |
| Servo | 17 | PWM |
| LCD SDA | 5 | |
| LCD SCL | 4 | |
| UART TX | 12 | hardware UART |
| UART RX | 13 | hardware UART |

Important: the LCD uses SDA = GP5 and SCL = GP4. That wiring is consistent across the Python, C++, and FreeRTOS versions.

## Requirements

For the Python version:

- A Raspberry Pi Pico
- `mpremote` installed: `pip install mpremote`

For the FreeRTOS version:

- A Raspberry Pi Pico
- Pico SDK 2.3.0 with the ARM toolchain
- Git, so the FreeRTOS kernel can be downloaded

## Entering BOOTSEL mode

Every flash step needs the Pico in BOOTSEL mode:

1. Unplug the Pico.
2. Hold the BOOTSEL button.
3. Plug the Pico back in while still holding BOOTSEL.
4. Release BOOTSEL.

The board should appear as a USB drive named `RPI-RP2`.

> If that drive never appears, try a different USB cable. Many cables are charge-only and do not carry data.

## Quick start: Python version

This is the teaching version. It lets the class see the lag immediately.

### Linux / macOS

```bash
cd SuperLoop
./scripts/flash_micropython.sh
./scripts/deploy_python.sh
```

### Windows PowerShell

```powershell
cd SuperLoop
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
./scripts/flash_micropython.ps1
./scripts/deploy_python.ps1
```

If Windows sees multiple COM ports, you can pick one explicitly:

```powershell
./scripts/deploy_python.ps1 -Port COM7
```

After upload, unplug and replug the Pico or press Ctrl-D in the REPL so `boot.py` runs.

## Quick start: FreeRTOS version

This is the responsive version that solves the lag.

### Linux / macOS

```bash
cd SuperLoop
./scripts/fetch_freertos.sh
./scripts/deploy_freertos.sh
```

### Windows PowerShell

```powershell
cd SuperLoop
./scripts/fetch_freertos.ps1
./scripts/deploy_freertos.ps1
```

The script builds the firmware and flashes it over USB if the Pico is already in BOOTSEL mode. If not, it falls back to copying the `.uf2` to the `RPI-RP2` drive.

## Watching UART on Windows

The long message in the demo is sent over the hardware UART pins, not over USB. That means you need a USB-to-UART adapter connected to:

- Pico TX = GP12
- Pico RX = GP13
- Pico GND = GND

Then connect the adapter to your Windows PC.

Use any serial terminal such as:

- PuTTY in Serial mode
- RealTerm
- Tera Term
- VS Code terminal with a serial monitor extension

Settings:

- Port: the COM port assigned by the USB-UART adapter
- Baud: 9600
- Data bits: 8
- Stop bits: 1
- Parity: none
- Flow control: none

You should see the long message repeat.

## The teaching demo in plain English

### Python superloop

The program does this in order:

1. blink LEDs
2. read the pot
3. move the servo
4. update the LCD
5. write a long message over UART
6. repeat

If step 5 is slow, the entire loop is slow. The LEDs freeze and the system feels laggy.

This is the lesson: one blocking operation can stall everything.

### FreeRTOS

The same work is moved into tasks. The long UART write is still there, but it is no longer allowed to monopolize the whole machine. The scheduler pauses the busy task and lets the rest of the system run.

This is the lesson: the system is responsive because work is scheduled, not because one loop is magically fast.

### Interrupts

FreeRTOS uses a hardware tick interrupt to drive the scheduler. That tick is what makes the system decide when to switch tasks. Without that interrupt, there is no real preemptive scheduling.

That is why the system feels more responsive in the RTOS version: the CPU is being reused by the scheduler instead of waiting for one loop to finish its long write.

## Files to look at

- `python/superloop/main.py` — the laggy superloop demonstration
- `python/superloop/hal.py` — the LED, ADC, servo, and UART wrappers
- `freertos/src/main.cpp` — the Task-based version that uses FreeRTOS
- `scripts/deploy_python.ps1` — Windows deployment for MicroPython
- `scripts/deploy_freertos.ps1` — Windows deployment for the RTOS build
- `TEACHING.md` — a more detailed lesson plan for teacher use

## Troubleshooting

### Python deploy fails

The Pico is probably still running a C++ or FreeRTOS image. Flash MicroPython first.

### No COM port appears on Windows

Check the USB-UART adapter driver. Try a different cable. Make sure the adapter is connected to the correct pins: GP12/TX, GP13/RX, GND.

### The Pico flashes but no UART output appears

Check the UART adapter wiring and confirm the baud rate is 9600. Also check that the board is running the correct version of the firmware.

### FreeRTOS image seems alive but nothing responds

Check the board still appears as a USB drive in BOOTSEL mode and that the script built the correct `.uf2` file.

## Simple takeaway

- Python superloop: laggy because one long write blocks everything.
- FreeRTOS: better because tasks yield and the scheduler shares time.
- Interrupts: the system is responsive because time is driven by hardware, not by one giant loop.

That is the whole lesson in one sentence.
