# Teaching guide: the superloop problem and the scheduler fix

This project is designed to teach one thing in a way students can see:

- One long blocking action makes the whole microcontroller feel slow.
- A scheduler fixes that by time-slicing work.
- A hardware interrupt drives the schedule and makes the system responsive.

The main path is:

1. Python superloop = slow and visibly laggy
2. FreeRTOS = same work, but split into tasks and scheduled
3. Interrupt/tick = the reason the scheduler works

The C++ version is only a reference comparison. It is not the main lesson.

## Stage 1: the Python superloop is laggy

Flash and run the Python build:

```bash
./scripts/flash_micropython.sh
./scripts/deploy_python.sh
```

Then open the file:

- `python/superloop/main.py`

The important part is the loop:

```python
while True:
    flash_leds(leds)
    angle = update_servo_from_pot(servo, pot)
    update_lcd_display(lcd, pot.read(), angle)
    long_running_message(uart)
    time.sleep_ms(1000)
```

That `long_running_message()` is the whole lesson.

It writes a long ASCII-art message over UART, one piece at a time, and it pauses between writes. During that time, the LEDs do not run, the LCD is not refreshed, and the system feels frozen.

Ask the class:

- What is stopping the LEDs from blinking?
- Why does the whole board feel laggy even though the code is still running?

The answer is simple: the loop is doing one long blocking action before it gets back to the next task.

## Stage 2: FreeRTOS makes it responsive

Build and flash the RTOS version:

```bash
./scripts/fetch_freertos.sh
./scripts/deploy_freertos.sh
```

Then open:

- `freertos/src/main.cpp`

The key change is that the work is now split into a task and yields with `vTaskDelay()` instead of blocking on a single long write.

This is the point to stress:

- The Python version is slow because there is only one loop.
- The FreeRTOS version is not magically faster.
- It is simply sharing time between tasks instead of letting one task monopolize the CPU.

That is why the system feels responsive again.

## Stage 3: the interrupt is what keeps it real

The key signal in the FreeRTOS build is the heartbeat:

```text
[tick     9360] superloop task alive and yielding
```

That number is not being updated by the application code. It advances because the hardware tick interrupt fires regularly and the FreeRTOS scheduler uses it to decide when to switch tasks.

This is the interrupt lesson:

- The scheduler is not just a loop.
- The scheduler is run by a timer interrupt.
- The interrupt gives the system a real timebase.

Without that interrupt, the system is only a loop. With it, the CPU can be shared fairly and the system becomes responsive.

## The class script

Keep it simple:

1. Run the Python version.
2. Show that the UART message stalls the loop.
3. Ask the students what is wrong with this design.
4. Run the FreeRTOS version.
5. Point out the scheduler and `vTaskDelay()`.
6. Explain the interrupt tick and why the system now feels responsive.

## Windows instructions for students and teacher

### Flash the Python image on Windows

```powershell
cd SuperLoop
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
./scripts/flash_micropython.ps1
./scripts/deploy_python.ps1
```

If the port is not auto-detected:

```powershell
./scripts/deploy_python.ps1 -Port COM7
```

### Flash the FreeRTOS image on Windows

```powershell
cd SuperLoop
./scripts/fetch_freertos.ps1
./scripts/deploy_freertos.ps1
```

### Watch the UART output on Windows

Connect a USB-to-UART adapter to the Pico:

- GP12 -> TX
- GP13 -> RX
- GND -> GND

Then open a serial terminal at 9600 baud, 8N1, no flow control.

Common tools:

- PuTTY
- RealTerm
- Tera Term
- VS Code serial monitor

The message will appear there, not over the USB CDC port.

## The one-sentence takeaway

A superloop blocks on a long write and everything feels laggy; a scheduler breaks that work into tasks so it can yield; and the interrupt gives the scheduler its clock so the system stays responsive.

## Optional extension

Ask the class: what happens if a button is checked every 10 ms?

- In the Python superloop, the button is delayed by the same long UART write.
- In FreeRTOS, the button task can run on time.
- With an interrupt, the button can be handled with even tighter latency.

That is exactly the progression from bare loop to scheduler to interrupt-driven real-time behavior.
