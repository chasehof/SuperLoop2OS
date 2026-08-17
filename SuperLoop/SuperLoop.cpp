#include <stdio.h>
#include "pico/stdlib.h"
#include "HAL.hpp"
#include "hardware/uart.h"
#include <array>
#include <iostream>
#include "lcd_i2c.hpp"


#define RED_LED_PIN 3
#define YELLOW_LED_PIN 2
#define GREEN_LED_PIN 0

#define POTENTIOMETER_PIN 26

#define LCD_SDA_PIN 4
#define LCD_SCL_PIN 5

#define SERVO_PIN 17

static void setup_leds(std::array<LED, 3>& leds) {
    for(LED& led : leds){
        led.init();
    }
}

static void flash_leds(std::array<LED, 3>& leds){
        for(LED& led : leds){
        led.turn_on();
        sleep_ms(5);
        led.turn_off();
    }
}

float update_servo_from_pot(Servo& servo, Potentiometer& pot) {
    // 1. Read the raw 12-bit ADC value from the potentiometer (0 to 4095)
    uint16_t pot_val = pot.read();

    // 2. Map the 0-4095 range to a 0.0f - 180.0f degree angle
    float angle = (static_cast<float>(pot_val) / 4095.0f) * 180.0f;

    // 3. Send the mapped angle to the servo
    servo.set_angle(angle);

    return angle;
}

static void update_lcd_display(LCD_I2C& lcd, uint16_t pot_val, float angle) {
    char buffer[17]; // 16 columns + 1 for null terminator

    // --- Line 0: Show Potentiometer Raw Value ---
    lcd.setCursor(0, 0); // Row 0, Column 0
    // Format string to pad spaces and overwrite old characters cleanly
    snprintf(buffer, sizeof(buffer), "Pot: %-11u", pot_val);
    lcd.writeString(buffer);

    // --- Line 1: Show Servo Angle ---
    lcd.setCursor(1, 0); // Row 1, Column 0
    snprintf(buffer, sizeof(buffer), "Angle: %-9.1f", angle);
    lcd.writeString(buffer);
}



int main()
{
    stdio_init_all();
    std::array<LED, 3> leds{LED{RED_LED_PIN}, LED{YELLOW_LED_PIN}, LED{GREEN_LED_PIN}};
    setup_leds(leds);
    Potentiometer pot{POTENTIOMETER_PIN};
    pot.init();

    Servo servo{SERVO_PIN};
    servo.init();

    // 1. Use the library's built-in Pico setup helper function
    // Parameters: (I2C Instance, SDA Pin, SCL Pin, Clock Speed in Hz)
    LCD_I2C_Setup(i2c0, LCD_SCL_PIN, LCD_SDA_PIN, 100000);

    // Parameters: (Address, Columns, Rows, I2C Instance)
    LCD_I2C lcd(0x27, 16, 2, i2c0);

    // 3. Print to the screen
    lcd.clear();
    lcd.setCursor(0, 0); // Note: Pi Pico version takes (line, position)
    lcd.writeString("Hello SARAH!!!!!");



    while (true) {
        printf("Hello, world!\n");
        flash_leds(leds);
        float angle = update_servo_from_pot(servo, pot);
        update_lcd_display(lcd, pot.read(), angle);
        lcd.writeString("servo angle: ");
        sleep_ms(1000);
    }
}
