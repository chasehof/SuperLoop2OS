#include "pico/stdlib.h"
#include "hardware/adc.h"
#include "hardware/i2c.h"
#include "hardware/pwm.h"

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

    constexpr explicit Potentiometer(uint gpio) : gpio_pin(gpio) {
    }
    
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
        
        // 1. Set clock divider: 125MHz / 125.0f = 1MHz (1 tick = 1 microsecond)
        pwm_set_clkdiv(slice_num, 125.0f);
        
        // 2. Set wrap for 20ms period (20,000 microseconds)
        pwm_set_wrap(slice_num, 19999); 
        
        // 3. Set initial neutral position (1500µs = 90 degrees)
        pwm_set_chan_level(slice_num, pwm_gpio_to_channel(gpio_pin), 1500);
        
        // 4. Enable the PWM slice
        pwm_set_enabled(slice_num, true);
    }

    void set_angle(float angle) {
        if (angle < 0.0f) angle = 0.0f;
        if (angle > 180.0f) angle = 180.0f;

        uint slice_num = pwm_gpio_to_slice_num(gpio_pin);
        
        // Map 0-180 degrees to 1000µs (1ms) - 2000µs (2ms) pulse width
        uint level = static_cast<uint>(1000.0f + (angle / 180.0f) * 1000.0f);
        
        pwm_set_chan_level(slice_num, pwm_gpio_to_channel(gpio_pin), level);
    }

private:
    uint gpio_pin{};
};
