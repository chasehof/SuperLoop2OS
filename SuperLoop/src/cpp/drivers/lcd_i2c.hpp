/**
 * @file LCD_I2C.hpp
 * @author Keith Standiford
 * @brief C++ Implementation for the Fast LCD I2C driver
 * @version 1.01
 * @date 2022-07-08
 * 
 * @copyright Copyright (c) 2022 Keith Standiford. All rights reserved. 
 * @remark Based loosely on the Pico SDK example and the Arduino LiquidCrystal API
 * @remark Compiles for Arduino or for Pi Pico
 * 
 */
#pragma once
//#define ARDUINO 

//  If we are compiling for Arduino, we need some extra files

#ifdef ARDUINO
#include <Arduino.h>
#include <inttypes.h>
#include <Print.h>
#include <Wire.h>
//  and some function alias'
inline void sleep_ms(uint32_t time) {delay(time);}
inline void sleep_us(uint64_t time) {delayMicroseconds(time);}
#else
#include <stdint.h>
#include <cstring>
#endif

//  For Arduino, we are part of the print class
//  For Pi Pico, we are stand alone
/**
 * @brief A class for *efficiently* driving an LDC display connected to the I2C bus on Arduino or Pi Pico
 * 
 * For the Arduino, the class is derived from the Print class so that all the Arduino Print or
 * write methods can be used.
 * 
 * For the Pi Pico, this is a stand-alone class.
 * \nosubgrouping
 * 
 */
#ifdef ARDUINO
class LCD_I2C : public Print {
#else
class LCD_I2C {
#endif
 private:

    using byte = uint8_t;

    // commands
    static constexpr byte  LCD_CLEARDISPLAY = 0x01;
    static constexpr byte  LCD_RETURNHOME = 0x02;
    static constexpr byte  LCD_ENTRYMODESET = 0x04;
    static constexpr byte  LCD_DISPLAYCONTROL = 0x08;
    static constexpr byte  LCD_DISPLAYSHIFT = 0x10;
    static constexpr byte  LCD_FUNCTIONSET = 0x20;
    static constexpr byte  LCD_SETCGRAMADDR = 0x40;
    static constexpr byte  LCD_SETDDRAMADDR = 0x80;

    // flags for display entry mode
    // use with LCD_ENTRYMODESET
    static constexpr byte  LCD_ENTRYRIGHT = 0x00;
    static constexpr byte  LCD_ENTRYLEFT = 0x02;
    static constexpr byte  LCD_DISPLAYENTRYSHIFT = 0x01;
    static constexpr byte  LCD_NODISPLAYENTRYSHIFT = 0x00;

    // flags for display and cursor control
    // use with LCD_DISPLAYCONTROL
    static constexpr byte  LCD_DISPLAYON = 0x04;
    static constexpr byte  LCD_DISPLAYOFF = 0x00;
    static constexpr byte  LCD_CURSORON = 0x02;
    static constexpr byte  LCD_CURSOROFF = 0x00;
    static constexpr byte  LCD_BLINKON = 0x01;
    static constexpr byte  LCD_BLINKOFF = 0x00;

    // flags for display and cursor shift
    // use with LCD_DISPLAYSHIFT
    static constexpr byte  LCD_DISPLAYMOVE = 0x08;
    static constexpr byte  LCD_CURSORMOVE = 0x00;
    static constexpr byte  LCD_MOVERIGHT = 0x04;
    static constexpr byte  LCD_MOVELEFT = 0x00;

    // flags for function set
    static constexpr byte  LCD_8BITMODE = 0x10;
    static constexpr byte  LCD_4BITMODE = 0x00;
    static constexpr byte  LCD_2LINE = 0x08;
    static constexpr byte  LCD_1LINE = 0x00;

    // Control bits in the I2C interface data words
    static constexpr byte  LCD_BACKLIGHT = 0x08;
    static constexpr byte  LCD_NOBACKLIGHT = 0x00;

    static constexpr byte  En = 0x4; // Enable bit
    static constexpr byte  Rw = 0x2; // Read/Write bit
    static constexpr byte  Rs = 0x1; // Register select bit

    static constexpr byte  ENABLE = En;

    // By default these LCD display drivers are on bus address 0x27

    // Modes for lcd_send_byte
    static constexpr byte  LCD_CHARACTER = 1;
    static constexpr byte  LCD_COMMAND = 0;

    static constexpr byte  MAX_LINES = 4;
    static constexpr byte  MAX_CHARS = 20;

    byte  _Addr;
    byte _displayfunction;
    byte _displaycontrol;
    byte _displaymode;
    byte _cols;
    byte _rows;
    byte _charsize = 0;     // used as boolean flag for 10 pixel high characters
    byte _backlight;
    byte _last_mode;

    uint8_t row_address_offset[MAX_LINES] = {0x80, 0xC0, 0x80 + 20, 0xC0 + 20};
    
    /*
     * For Arduino, the I2C interface (Wire) has an internal buffer
     * The buffer length is defined as BUFFER_LENGTH.
     * Care MUST be taken, since ONLY BUFFER_LENGTH characters can be sent 
     * in a singe transmission, and excess characters will be discarded.
     * Note that BUFFER_LENGTH varies and can be quite short. UNO is about 30
     * characters, while the Pi Pico implementation is over 120! 
     * 
     * In the Pi Pico SDK, the I2C interface does not buffer, so we can set the
     * size to suit ourselves.
     * 
     * Note that we will ALWAYS buffer internally and transmit in a block, since
     * testing with Arduino showed that it was faster than sending single bytes
     * to the Arduino Wire routines.
     * */
    #ifdef ARDUINO
        // The default Arduino length definition is BUFFER_LENGTH
        // The Pi Pico Arduino version of wire.h defines a DIFFERENT variable name
        // than some of the other Arduino environments. So we will check!
        // If we can't find a length we will assume 30 bytes...
        #ifndef BUFFER_LENGTH
            #ifdef WIRE_BUFFER_SIZE
                static constexpr size_t  BUFFER_LENGTH = WIRE_BUFFER_SIZE;
            #else
                static constexpr size_t  BUFFER_LENGTH = 30;
            #endif
        #endif
    #else
    static constexpr size_t  BUFFER_LENGTH = 128;
    #endif

    byte _buffer[BUFFER_LENGTH];


    /*
     * This is the buffer pointer (and character counter).
     * 
     */
    size_t _bufferIn = 0;  

    /*
     * The Pico system needs to know which I2C hardware to use, so we need
     * to save it! Note that on Arduino systems with more than one I2C bus,
     * only the first one pointed to by wire can be used!
    */
    #ifndef ARDUINO
    i2c_inst *I2C_instance {nullptr};
    #endif

    /**
     * Output a byte to the interface chip.
     *
     * @param val Value to be written
     * @param Enable_Buffering If true, data is added to the output buffer.
     * If false or missing, data is added to the output buffer and the buffer
     * is immediately written to the display. 
     */
    void write_byte(byte val, bool Enable_Buffering = false)  noexcept;

    /**
     * Output a byte to the display as two 4 bit nibbles.
     *
     * @param val Value to be written
     * @param mode Specifies command or data mode bits 'or'ed with data
     * @param Enable_Buffering If true, data is added to the output buffer.
     * If false or missing, data is added to the output buffer and the buffer
     * is immediately written to the display. 
     */
    void send_byte(byte val, int mode, bool Enable_Buffering = false)  noexcept;

    /**
     * Helper function to put the display in a known state.
     *
     * In 4 bit mode, cleared, with the cursor at 0,0
     * Display enabled, backlight on
     */
    void init()  noexcept;


 public:

 #ifdef ARDUINO
 // DO NOT Document for Arduino
 ///@cond
 #endif

    /**
     * @brief A reminder of the size of custom character arrays
     * 
     */
    static constexpr uint8_t CUSTOM_SYMBOL_SIZE = 8;

    /** @brief needed for Arduino Constructor */
    static constexpr byte  LCD_5x10DOTS = 0x04; 
    /** @brief needed for Arduino Constructor */
    static constexpr byte  LCD_5x8DOTS = 0x00; 
#ifdef ARDUINO
// end conditional documentation and begin Arduino_diff group
///@endcond
#endif

    /* Public API */
#ifdef ARDUINO
    LCD_I2C(uint8_t lcd_addr, uint8_t lcd_cols, uint8_t lcd_rows, uint8_t charsize = 0);
#else
    LCD_I2C(byte address, byte columns, byte rows, i2c_inst * I2C);
#endif

    void clear();
    void home();

#ifdef ARDUINO
    void setCursor(byte position, byte line, bool Enable_Buffering = false);
#else
    void setCursor(byte line, byte position, bool Enable_Buffering = false);
#endif

    void writeString(const char s[], bool Enable_Buffering = false);
    void writeChar(byte c, bool Enable_Buffering = false);
    size_t write(const uint8_t *buffer, size_t size, bool Enable_Buffering = false);

    int show();
    void backlight(void);
    void noBacklight();
    void cursor(void);
    void noCursor(void);
    void blink(void);
    void noBlink(void);
    void display(void);
    void noDisplay(void);
    void scrollDisplayLeft(void);
    void scrollDisplayRight(void);
    void autoscroll(void);
    void noAutoscroll(void);
    void rightToLeft(void);
    void leftToRight(void);
    void createChar(byte charnum, const byte char_map[]);


};

#ifndef ARDUINO
extern "C" int LCD_I2C_Setup(i2c_inst_t* I2C, uint SDA_Pin, uint SCL_Pin, uint I2C_Clock);
#endif


