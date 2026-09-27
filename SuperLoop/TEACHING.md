# Teaching SuperLoop: why an operating system is worth it

A single demo application, written three ways, used to build the argument that
scheduling and interrupts are not optional complexity. Each variant drives the
same hardware: three LEDs, a potentiometer on the ADC, a servo, an I2C LCD, and
a long message over UART.

## The through-line

Each variant adds exactly one new idea, and each idea fixes a specific,
*observable* defect in the one before it. Do not skip a stage — the failure at
each stage is the setup for the next.

| Stage | Variant | Adds | The problem it fixes |
| --- | --- | --- | --- |
| 1 | `python/` | nothing — a bare loop | establishes how bad it is |
| 2 | `freertos/` | preemptive time-slicing | one slow thing no longer starves everything |
| 3 | `freertos/` | the tick interrupt | explains *how* preemption actually happens |

`src/cpp/` is the same bare loop in C++. It is not part of the argument so much
as a control: it shows the Python version is not slow because of Python, it is
slow because of the loop.

## Stage 1 - the superloop (MicroPython)

Flash and run:

```bash
./scripts/flash_micropython.sh
./scripts/deploy_python.sh
```

Read `python/superloop/main.py`. The entire program is one `while True` loop
that does every job in sequence: blink the LEDs, read the pot, move the servo,
update the LCD, write a long string to the UART, sleep.

Ask the class: **if the UART write is slow, what stops working?**

Then make them find the answer. The point to land: nothing stops, but nothing
*else runs either*. `long_running_message()` writes roughly 150 characters with
a delay per character, so for more than a second the LEDs are frozen and the
potentiometer is not sampled. The system is not broken — it is serial, and
serial is the bug.

Things worth pointing out in the source:

- `time.sleep_ms()` is a *blocking* call. It parks the whole machine, not just
  the caller. There is no other caller.
- There is no notion of "importance". A cosmetic LED blink and a sensor read
  occupy the same thread, so they are equally worth stalling for.
- `hal.py` deliberately wraps every `machine` import in `try/except ImportError`.
  That is what lets this exact package import on a desktop CPython interpreter
  for inspection.

## Stage 2 - preemptive scheduling (FreeRTOS)

Same logic, now as a task:

```bash
./scripts/fetch_freertos.sh   # once
./scripts/deploy_freertos.sh
```

Read `freertos/src/main.cpp`. Ask what changed.

The answer is `vTaskDelay()` replacing `sleep_ms()`, and — this is the part that
matters — `vTaskDelay()` *returns*. It hands the CPU back to the scheduler
instead of sitting in a busy wait. The loop body is otherwise nearly identical.

Confirm it on the board. The FreeRTOS build prints a heartbeat:

```
[tick     9360] superloop task alive and yielding
[tick    12453] superloop task alive and yielding
```

The tick advances at exactly `configTICK_RATE_HZ` (1000/sec). Contrast that
with stage 1, where the only timing in the system is whatever the loop happens
to be doing. The board now has a clock, which is the precondition for deciding
that anything is late.

## Stage 3 - the interrupt that makes it work

The heartbeat is worth dwelling on, because it is the least obvious part.

Nobody called a function to make that number go up. SysTick fires 1000 times a
second from hardware, and its handler is what advances the tick. Ask the class
where that number is coming from, and let them find `FreeRTOSConfig.h` and the
port's `isr_systick`.

This is the point of the whole exercise: **preemption is not cooperative.** The
running task cannot choose to be interrupted, and does not need to cooperate. The
scheduler works because a hardware timer takes the CPU away on a fixed schedule,
which is why a task that forgets to yield still cannot starve its neighbours.

Worth noting: the heartbeat is guarded by `stdio_usb_connected()` so the task
can never block on a full USB buffer. That guard is a scheduling concern hiding
inside a print statement — a good prompt for "what else in this program could
block?"

## The optional exercise that ties it together

Ask: add a button on a fourth GPIO that must be sampled every 10 ms to debounce
a switch.

- In stage 1 there is nowhere to put it. The only way to poll it is inside the
  existing loop, where its latency is however long the UART message takes.
- In stage 2 it is a second task with a short period, and it simply works —
  because `vTaskDelay()` yields.
- In stage 3 you can also make it a hardware interrupt or a timer callback, and
  now the latency is bounded by the hardware rather than by the scheduler's
  tick.

That progression — poll badly, poll well, get interrupted — is the shape of most
real-time firmware, and it is the argument the three variants are built to make.

## Why the C++ bare-loop variant exists

`src/cpp/` is the identical bare loop in native code. It is useful for exactly
one demonstration: if students conclude that stage 1 is slow *because it is
Python*, flashing the C++ version and watching it be equally unresponsive
settles the question. The problem was never the language. It was the loop.

## A trap to expect

If students build the FreeRTOS variant and the board flashes but then vanishes
from USB entirely, the fault is almost always the exception handlers.
`configUSE_DYNAMIC_EXCEPTION_HANDLERS` defaults to `1`, and at that setting the
RP2040 port does not alias `vPortSVCHandler` / `xPortPendSVHandler` /
`xPortSysTickHandler` onto the SDK's `isr_svcall` / `isr_pendsv` /
`isr_systick`. Nothing references them, the linker discards them, the vector
table keeps the SDK's empty defaults, and `vTaskStartScheduler()` faults before
any task runs. `freertos/include/FreeRTOSConfig.h` sets it to `0`; that one line
is the difference between a working demo and a board that looks bricked.

To make students see it, they can check the linked image:

```bash
arm-none-eabi-nm build/freertos/SuperLoop_FreeRTOS.elf | grep isr_sys
```

Strong `T` means the scheduler will start. Weak `W` means it will not, no matter
how convincingly the flashing appeared to work.
