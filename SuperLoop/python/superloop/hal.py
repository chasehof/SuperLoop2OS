import time
try:
    from machine import ADC, I2C, Pin, PWM, UART
except ImportError:
    ADC = None
    I2C = None
    Pin = None
    PWM = None
    UART = None

RED_LED_PIN = 3
YELLOW_LED_PIN = 2
GREEN_LED_PIN = 0

POTENTIOMETER_PIN = 26
SERVO_PIN = 17

# These must match src/cpp/SuperLoop.cpp so all three variants drive the same
# wiring. LCD_I2C_Setup() in the C++ build takes (bus, SDA, SCL, clock), and the
# original code passed SCL before SDA -- so the physical wiring is SDA=GP5,
# SCL=GP4 even though the old #defines said the opposite.
LCD_SDA_PIN = 5
LCD_SCL_PIN = 4

# GP0/GP1 are the USB connector on a Pico, so use the same dedicated UART pins
# as the C++ variant instead.
UART_TX_PIN = 12
UART_RX_PIN = 13
UART_BAUD_RATE = 9600


class LED:
    def __init__(self, pin: int):
        self.gpio_pin = pin
        self.pin = Pin(pin, Pin.OUT) if Pin is not None else None

    def init(self):
        if self.pin is None:
            return
        self.pin.init(Pin.OUT)

    def turn_on(self):
        if self.pin is not None:
            self.pin.value(1)

    def turn_off(self):
        if self.pin is not None:
            self.pin.value(0)


class Potentiometer:
    def __init__(self, gpio: int):
        self.gpio_pin = gpio
        self.adc = ADC(Pin(gpio)) if ADC is not None and Pin is not None else None

    def init(self):
        if self.adc is not None:
            return

    def read(self) -> int:
        if self.adc is None:
            return 0
        return int(self.adc.read_u16() >> 4)


class Servo:
    def __init__(self, pin: int):
        self.gpio_pin = pin
        self.pwm = PWM(Pin(pin)) if PWM is not None and Pin is not None else None

    def init(self):
        if self.pwm is None:
            return
        self.pwm.freq(50)
        self.set_angle(90.0)

    def set_angle(self, angle: float):
        if self.pwm is None:
            return
        angle = max(0.0, min(180.0, float(angle)))
        pulse_width_us = 1000.0 + (angle / 180.0) * 1000.0
        duty = int((pulse_width_us / 20000.0) * 65535.0)
        self.pwm.duty_u16(duty)


class UART_Sensor:
    def __init__(self, uart_port: int, tx_pin: int, rx_pin: int, baud_rate: int = UART_BAUD_RATE):
        self.uart_port = uart_port
        self.tx_pin = tx_pin
        self.rx_pin = rx_pin
        self.baud_rate = baud_rate
        self.uart = None

    def init(self):
        if UART is None:
            return
        self.uart = UART(self.uart_port, baudrate=self.baud_rate, tx=Pin(self.tx_pin), rx=Pin(self.rx_pin))

    def print(self, message: str):
        if self.uart is None:
            return
        self.uart.write(message.encode("utf-8"))
