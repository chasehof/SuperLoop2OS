import time
from .drivers.lcd_i2c import LCD_I2C
from .hal import (
    GREEN_LED_PIN,
    LCD_SCL_PIN,
    LCD_SDA_PIN,
    POTENTIOMETER_PIN,
    RED_LED_PIN,
    SERVO_PIN,
    UART_BAUD_RATE,
    UART_RX_PIN,
    UART_Sensor,
    UART_TX_PIN,
    YELLOW_LED_PIN,
    LED,
    Potentiometer,
    Servo,
)

try:
    from machine import I2C, Pin
except ImportError:
    I2C = None
    Pin = None

def setup_leds(leds):
    for led in leds:
        led.init()

def flash_leds(leds):
    for led in leds:
        led.turn_on()
        time.sleep_ms(5)
        led.turn_off()

def update_servo_from_pot(servo, pot):
    pot_val = pot.read()
    angle = (pot_val / 4095.0) * 180.0
    servo.set_angle(angle)
    return angle

def update_lcd_display(lcd, pot_val, angle):
    lcd.set_cursor(0, 0)
    lcd.write_string(f"Pot: {pot_val:<11}")
    lcd.set_cursor(1, 0)
    lcd.write_string(f"Angle: {angle:<9.1f}")

def long_running_message(uart):
    message = r"""
    _____________________
    < Wow what a long message!   >
    ---------------------
            \   ^__^
            \  (oo)\_______
                (__ )\       )\/\
                    ||----w |
                    ||     ||
        """
    uart.print(message)
    uart.print("\n")

def main():
    uart = UART_Sensor(0, UART_TX_PIN, UART_RX_PIN, UART_BAUD_RATE)
    uart.init()
    uart.print("=== UART Sensor Initialized at 9600 Baud ===\n")

    leds = [LED(RED_LED_PIN), LED(YELLOW_LED_PIN), LED(GREEN_LED_PIN)]
    setup_leds(leds)

    pot = Potentiometer(POTENTIOMETER_PIN)
    pot.init()

    servo = Servo(SERVO_PIN)
    servo.init()

    if I2C is not None and Pin is not None:
        i2c = I2C(0, sda=Pin(LCD_SDA_PIN), scl=Pin(LCD_SCL_PIN), freq=100000)
    else:
        i2c = None

    lcd = LCD_I2C(0x27, 16, 2, i2c)
    lcd.clear()

    while True:
        flash_leds(leds)
        angle = update_servo_from_pot(servo, pot)
        update_lcd_display(lcd, pot.read(), angle)
        long_running_message(uart)
        time.sleep_ms(1000)

if __name__ == "__main__":
    main()
