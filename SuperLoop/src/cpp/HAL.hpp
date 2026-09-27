#pragma once
#include "pico/stdlib.h"
#include "hardware/adc.h"
#include "hardware/i2c.h"
#include "hardware/pwm.h"
#include "hardware/uart.h"

class UART_Sensor {
    public:
    explicit UART_Sensor(uart_inst_t* uart_port, uint tx_pin, uint rx_pin, uint baud_rate = 9600) 
        : uart_port(uart_port), tx_pin(tx_pin), rx_pin(rx_pin), baud_rate(baud_rate) {}

    void init() {
        uart_init(uart_port, baud_rate);
        gpio_set_function(tx_pin, GPIO_FUNC_UART);
        gpio_set_function(rx_pin, GPIO_FUNC_UART);
    }

    void print(const char* message) {
        uart_puts(uart_port, message);
    }

    void putc(char c) {
        uart_putc_raw(uart_port, c);
    }

    private:
    uart_inst_t* uart_port{};
    uint tx_pin{};
    uint rx_pin{};
    uint baud_rate{};
};

class LED {
    public: 
    explicit constexpr LED(int pin) : gpio_pin(pin) {}

    void init() {
        gpio_init(gpio_pin);
        gpio_set_dir(gpio_pin, GPIO_OUT);
    }

    void turn_on() {
        gpio_put(gpio_pin, 1);
    }

    void turn_off() {
        gpio_put(gpio_pin, 0);
    }

    private:
    int gpio_pin{};
};

class Potentiometer {
    public:
    constexpr explicit Potentiometer(uint gpio) : gpio_pin(gpio) {}
    
    void init() {
        adc_init();
        adc_gpio_init(gpio_pin);
    }
    
    uint16_t read () {
        adc_select_input(gpio_pin - 26);
        return adc_read();
    }
    
    private:
    uint gpio_pin{};
};


class Servo {
public:
    explicit Servo(uint pin) : gpio_pin(pin) {}

    void init() {
        gpio_set_function(gpio_pin, GPIO_FUNC_PWM);
        uint slice_num = pwm_gpio_to_slice_num(gpio_pin);
        pwm_set_clkdiv(slice_num, 125.0f);
        pwm_set_wrap(slice_num, 19999); 
        pwm_set_chan_level(slice_num, pwm_gpio_to_channel(gpio_pin), 1500);
        pwm_set_enabled(slice_num, true);
    }

    void set_angle(float angle) {
        if (angle < 0.0f) angle = 0.0f;
        if (angle > 180.0f) angle = 180.0f;

        uint slice_num = pwm_gpio_to_slice_num(gpio_pin);
        uint level = static_cast<uint>(1000.0f + (angle / 180.0f) * 1000.0f);
        pwm_set_chan_level(slice_num, pwm_gpio_to_channel(gpio_pin), level);
    }

private:
    uint gpio_pin{};
};
