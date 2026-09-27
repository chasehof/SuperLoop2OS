# SuperLoop - one application, three runtimes

A single demo application written three ways, used to show **why an operating
system is worth the complexity**. Each variant drives the same hardware:

- 3 LEDs blinking in sequence
- Potentiometer read over ADC
- Servo angle mapped from the potentiometer
- A long ASCII-art message written over UART
- 16x2 I2C LCD showing live values

| Variant | Language | Scheduler | What it teaches |
| --- | --- | --- | --- |
| `python/` | MicroPython | None (bare loop) | The superloop problem: one long task blocks everything else |
| `freertos/` | C++ | FreeRTOS preemptive | Time-slicing, `vTaskDelay`, the tick, priorities |
| `src/cpp/` | C++ | None (bare loop) | Same superloop in native code, for comparison with FreeRTOS |

The narrative for class: start with `python/`. Every device on the bus shares
one thread of execution, so the blocking LCD write and the multi-second UART
message starve the LEDs. Then show the identical logic in `freertos/`, where
each of those is a *task* that yields at `vTaskDelay`, and all of them make
progress.

**See `TEACHING.md` for the lesson outline** - the stage-by-stage sequence, what
to ask the class at each point, and the exercise that ties it together.

## Wiring

All three variants use the same pins.

| Signal | Pico GPIO | Notes |
| --- | --- | --- |
| Red / Yellow / Green LED | 3 / 2 / 0 | Onboard LED is GP25; these are external |
| Potentiometer | 26 (ADC0) | |
| Servo | 17 (PWM) | |
| LCD SDA | 5 | |
| LCD SCL | 4 | |
| UART TX / RX | 12 / 13 | 9600 baud, **not** USB |

> The LCD SDA/SCL pair is easy to get backwards. `LCD_I2C_Setup()` takes
> `(bus, SDA, SCL, clock)`, and the original code passed SCL before SDA, so the
> labels in the source used to disagree with the pins actually driven. The
> defines have been corrected to match the real wiring, so SDA is GP5 and SCL is
> GP4 everywhere.

## Requirements

- Raspberry Pi Pico (or Pico W, see board notes below)
- [Pico SDK 2.3.0](https://github.com/raspberrypi/pico-sdk) with the ARM
  toolchain, which installs `cmake`, `ninja` and `picotool` under
  `~/.pico-sdk` (Linux/macOS) or `%USERPROFILE%\.pico-sdk` (Windows)
- MicroPython users only: `pip install mpremote`
- FreeRTOS users only: `git` (to fetch the kernel)

The scripts add the SDK's `cmake`/`ninja`/`picotool` to `PATH` themselves, so
you do not need to configure your shell.

## Entering BOOTSEL mode

Every flashing step needs the Pico in BOOTSEL mode:

1. Unplug the Pico.
2. **Hold the BOOTSEL button** (small button on the top edge).
3. Plug the Pico back in, still holding BOOTSEL.
4. Release BOOTSEL.

The board then appears as a removable drive named `RPI-RP2`. **If the drive never
appears, try a different USB cable** - many cables are charge-only and cannot
carry data. This is the single most common reason flashing appears to fail.

## Linux / macOS

```bash
cd SuperLoop

# ---- FreeRTOS (preemptive scheduling) ----
./scripts/fetch_freertos.sh      # once
./scripts/deploy_freertos.sh     # build + flash

# ---- C++ superloop (bare metal, for comparison) ----
./scripts/run_cpp.sh             # build only
./scripts/deploy_cpp.sh          # flash

# ---- MicroPython superloop ----
./scripts/flash_micropython.sh    # once per switch back to Python
./scripts/deploy_python.sh       # upload the package
```

## Windows (PowerShell)

Run from the `SuperLoop` directory. Execution policy may block the scripts on a
fresh machine; if so, either use the one-liner below or unblock the files once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

cd SuperLoop

# ---- FreeRTOS (preemptive scheduling) ----
.\scripts\fetch_freertos.ps1     # once
.\scripts\deploy_freertos.ps1    # build + flash

# ---- C++ superloop ----
.\scripts\run_cpp.ps1            # build only
.\scripts\deploy_cpp.ps1         # flash

# ---- MicroPython superloop ----
.\scripts\flash_micropython.ps1  # once per switch back to Python
.\scripts\deploy_python.ps1      # upload the package
```

Two Windows-specific notes:

- **Drive letters vary.** The scripts locate the Pico by reading
  `INFO_UF2.TXT` and matching `Board-ID: RPI-RP2`, not by assuming a letter like
  `E:`. If Windows has never seen the board, it may not assign a letter until
  you open it in File Explorer once.
- **COM port varies.** `deploy_python.ps1` auto-detects the port. If the Pico has
  other serial devices, pass it explicitly: `.\scripts\deploy_python.ps1 -Port COM7`

macOS has no BOOTSEL mass-storage volume in some setups; if
`flash_micropython.sh` cannot find `RPI-RP2`, drag the downloaded UF2 onto the
Pico in Finder instead.

## Board notes

The scripts default to a plain Pico (`PICO`, `PICO_BOARD=pico`). For a Pico W:

```bash
BOARD=PICOW ./scripts/flash_micropython.sh     # MicroPython
```

and set `PICO_BOARD=pico_w` when configuring the native builds.

## Seeing the output

The FreeRTOS and C++ builds print over the USB CDC port at **115200 baud**. The
repeated UART art in the demo goes out the *hardware* UART on GP12/GP13, so you
need a USB-TTL adapter on those pins to see it.

The FreeRTOS build also emits a heartbeat line per loop:

```
[tick     9360] superloop task alive and yielding
```

Two things to point out in class:

- The tick advances at exactly `configTICK_RATE_HZ` (1000/sec). That is the
  SysTick interrupt driving preemption - it is the "interrupts" part of the
  lesson, and it is what the stock superloop has no equivalent of.
- The heartbeat is guarded by `stdio_usb_connected()` so the task can never
  block on a full USB buffer with nothing attached. That guard is itself a
  scheduling concern worth discussing.

## Why FreeRTOS needs specific configuration

`freertos/include/FreeRTOSConfig.h` carries three settings that are easy to miss.
If `configUSE_DYNAMIC_EXCEPTION_HANDLERS` is left at its default of `1`, the RP2040
port does not alias `vPortSVCHandler` / `xPortPendSVHandler` /
`xPortSysTickHandler` onto the SDK's `isr_svcall` / `isr_pendsv` / `isr_systick`.
Nothing references them, `--gc-sections` strips them, the vector table keeps the
SDK's empty defaults, and `vTaskStartScheduler()` faults before any task runs -
the board flashes fine and then vanishes from USB. Setting it to `0` is what
makes the scheduler start.

`freertos/CMakeLists.txt` likewise must use `portable/ThirdParty/GCC/RP2040`,
not the generic `portable/GCC/ARM_CM0` port, for the same reason.

## Layout

```
CMakeLists.txt         top-level build; FreeRTOS is an add_subdirectory of this
src/cpp/               C++ superloop (bare metal)
  SuperLoop.cpp        the loop, and the pin defines
  HAL.hpp              LED, Potentiometer, Servo, UART_Sensor
  drivers/lcd_i2c.*    I2C LCD driver, shared with the FreeRTOS variant
python/                MicroPython package -> copied to the Pico filesystem
  boot.py              entry point, runs superloop.main()
  superloop/hal.py     LED, Potentiometer, Servo, UART_Sensor
  superloop/main.py    the same loop, in Python
freertos/              FreeRTOS variant
  src/main.cpp         the same loop, now as a task
  src/port_helpers.c   static memory for the Idle and Timer tasks
  include/FreeRTOSConfig.h
scripts/               build and flash scripts (bash + PowerShell)
TEACHING.md            lesson outline: what to show, in what order, and why
```

`src/cpp/HAL.hpp` and `src/cpp/drivers/lcd_i2c.*` are shared by the C++ and
FreeRTOS variants, so only the scheduling layer differs between them.

## Troubleshooting

**Board flashes but never shows up on USB.** Almost always the exception-handler
problem above. Confirm with
`arm-none-eabi-nm build/freertos/SuperLoop_FreeRTOS.elf | grep isr_sys` - the
symbols should be strong `T`, not weak `W`.

**`mpremote` cannot connect.** The board is probably running the C++ or FreeRTOS
image, which has no MicroPython REPL. Flash MicroPython first.

**`cmake: command not found`.** The SDK is not installed, or the script predates
the PATH setup. All current scripts set PATH themselves.

**No LCD output.** Check SDA is on GP5 and SCL on GP4, and that the LCD address
is `0x27` (some modules are `0x3F`).
