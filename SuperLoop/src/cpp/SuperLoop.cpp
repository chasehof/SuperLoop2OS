#include <stdio.h>
#include "pico/stdlib.h"
#include "HAL.hpp"
#include "hardware/uart.h"
#include <array>
#include <iostream>
#include "drivers/lcd_i2c.hpp"


#define RED_LED_PIN 3
#define YELLOW_LED_PIN 2
#define GREEN_LED_PIN 0

#define POTENTIOMETER_PIN 26

// These match the wiring that the FreeRTOS and MicroPython variants use.
// Note LCD_I2C_Setup's signature is (bus, SDA, SCL, clock) -- the original code
// passed SCL then SDA, so the labels below used to be swapped relative to the
// pins actually driven.
#define LCD_SDA_PIN 5
#define LCD_SCL_PIN 4

#define SERVO_PIN 17

#define UART_TX_PIN 12
#define UART_RX_PIN 13
#define UART_BAUD_RATE 9600

static void setup_leds(std::array<LED, 3>& leds) {
    for(LED& led : leds){
        led.init();
    }
}

static void flash_leds(std::array<LED, 3>& leds){
        for(LED& led : leds){
        led.turn_on();
        sleep_ms(500);
        led.turn_off();
    }
}

float update_servo_from_pot(Servo& servo, Potentiometer& pot) {
    uint16_t pot_val = pot.read();
    float angle = (static_cast<float>(pot_val) / 4095.0f) * 180.0f;
    servo.set_angle(angle);
    return angle;
}

static void update_lcd_display(LCD_I2C& lcd, uint16_t pot_val, float angle) {
    char buffer[17];
    lcd.setCursor(0, 0);
    snprintf(buffer, sizeof(buffer), "Pot: %-11u", pot_val);
    lcd.writeString(buffer);
    lcd.setCursor(1, 0);
    snprintf(buffer, sizeof(buffer), "Angle: %-9.1f", angle);
    lcd.writeString(buffer);
}

static void long_running_message(UART_Sensor& uart) {
    const char* art = R"(


    THIS DEVICE IS NOW BUSY RUNNING A HUGE BLOCKING TASK
    NO OTHER WORK WILL HAPPEN UNTIL IT FINISHES

    Press RESET to regain control.
    )";

    // Print art slowly, character-by-character to simulate a blocking long task
    for (const char* p = art; *p != '\0'; ++p) {
        uart.putc(*p);
        sleep_ms(10); // tweak this delay to make it longer/shorter
    }
    uart.print("\n");
}


int main()
{
    stdio_init_all();
    UART_Sensor uart(uart0, UART_TX_PIN, UART_RX_PIN, UART_BAUD_RATE);
    uart.init();
    uart.print("=== UART Sensor Initialized at 9600 Baud ===\n");
    std::array<LED, 3> leds{LED{RED_LED_PIN}, LED{YELLOW_LED_PIN}, LED{GREEN_LED_PIN}};
    setup_leds(leds);
    Potentiometer pot{POTENTIOMETER_PIN};
    pot.init();

    Servo servo{SERVO_PIN};
    servo.init();

    LCD_I2C_Setup(i2c0, LCD_SDA_PIN, LCD_SCL_PIN, 100000);
    LCD_I2C lcd(0x27, 16, 2, i2c0);
    lcd.clear();
    lcd.setCursor(0, 0);

    while (true) {
        flash_leds(leds);
        float angle = update_servo_from_pot(servo, pot);
        update_lcd_display(lcd, pot.read(), angle);
        long_running_message(uart);
        sleep_ms(100);
    }
}
