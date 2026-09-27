import time
try:
    from machine import I2C, Pin
except ImportError:
    I2C = None
    Pin = None


class LCD_I2C:
    def __init__(self, address: int = 0x27, cols: int = 16, rows: int = 2, bus=None):
        self.address = address
        self.cols = cols
        self.rows = rows
        self.bus = bus or self._default_bus()
        self.backlight = 0x08
        self._init()

    def _default_bus(self):
        if I2C is None or Pin is None:
            return None
        return I2C(0, sda=Pin(4), scl=Pin(5), freq=100000)

    def _write4bits(self, value: int, mode: int = 0):
        if self.bus is None:
            return
        nibble = (value & 0xF0) | self.backlight | mode
        self.bus.writeto(self.address, bytes([nibble, nibble | 0x04]))
        time.sleep_us(1)
        self.bus.writeto(self.address, bytes([nibble & ~0x04, nibble]))
        nibble = ((value << 4) & 0xF0) | self.backlight | mode
        self.bus.writeto(self.address, bytes([nibble, nibble | 0x04]))
        time.sleep_us(1)
        self.bus.writeto(self.address, bytes([nibble & ~0x04, nibble]))

    def _send(self, value: int, mode: int = 0):
        self._write4bits(value, mode)
        time.sleep_us(50)

    def command(self, value: int):
        self._send(value, 0)

    def write(self, value: int):
        self._send(value, 1)

    def clear(self):
        self.command(0x01)
        time.sleep_ms(2)

    def set_cursor(self, row: int, col: int):
        row_offsets = [0x00, 0x40, 0x14, 0x54]
        if row < 0 or row >= self.rows:
            row = 0
        if col < 0 or col >= self.cols:
            col = 0
        self.command(0x80 | (col + row_offsets[row]))

    def write_string(self, text: str):
        for char in str(text):
            self.write(ord(char))

    def _init(self):
        time.sleep_ms(50)
        self._write4bits(0x30, 0)
        time.sleep_ms(5)
        self._write4bits(0x30, 0)
        time.sleep_us(150)
        self._write4bits(0x30, 0)
        self._write4bits(0x20, 0)
        self.command(0x20)
        self.command(0x04)
        self.clear()
        self.command(0x04)
