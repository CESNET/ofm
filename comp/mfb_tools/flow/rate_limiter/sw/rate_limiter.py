############################################################
# rate_limiter.py: Rate Limiter component class
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Tomas Hak <xhakto01@vut.cz>
############################################################

import nfb


class RateLimiter(nfb.BaseComp):
    """Rate Limiter component class

    This class mediates the HW component address space and communication protocol.
    """

    # DevTree compatible string
    DT_COMPATIBLE = "cesnet,ofm,rate_limiter"

    # MI ADDRESS SPACE
    _REG_STATUS  = 0x00
    _REG_SEC_LEN = 0x04
    _REG_INT_LEN = 0x08
    _REG_INT_CNT = 0x0c
    _REG_FREQ    = 0x10
    _REG_SPEED   = 0x14

    # STATUS REGISTER FLAGS
    _SR_IDLE_FLAG    = 0x01
    _SR_CONF_FLAG    = 0x02
    _SR_RUN_FLAG     = 0x04
    _SR_PTR_RST_FLAG = 0x08

    def __init__(self, **kwargs):
        """Constructor"""

        try:
            super().__init__(**kwargs)
            self._name = "Rate Limiter"
            if "index" in kwargs:
                self._name += " " + str(kwargs.get("index"))
        except:
            print("Error while opening Rate Limiter component!")

    def _conv_Gbs2Bscn(self, speed, sec_len, freq):
        """Convert Gb/s to B/section"""

        ticks_per_sec    = freq * 1_000_000
        sections_per_sec = ticks_per_sec / sec_len
        bytes_per_sec    = speed * 125_000_000
        return (int)(bytes_per_sec / sections_per_sec)

    def _conv_Bscn2Gbs(self, speed, sec_len, freq):
        """Convert B/section to Gb/s"""

        ticks_per_sec    = freq * 1_000_000
        sections_per_sec = ticks_per_sec / sec_len
        bytes_per_sec    = speed * sections_per_sec
        return (int)(bytes_per_sec / 125_000_000)

    def get_frequency(self):
        """Retrieve frequency in Hz"""

        return self._comp.read32(self._REG_FREQ) * 1_000_000

    def print_cfg(self):
        """Print current configuration"""

        try:
            status     = self._comp.read32(self._REG_STATUS)
            sec_len    = self._comp.read32(self._REG_SEC_LEN)
            max_speeds = self._comp.read32(self._REG_INT_CNT)
            frequency  = self._comp.read32(self._REG_FREQ)

            status_s     = "Idle"
            if (status == self._SR_CONF_FLAG):
                status_s = "Configuration"
            elif (status == self._SR_RUN_FLAG):
                status_s = "Running traffic shaping"

            speed_reg     = self._REG_SPEED
            output_speeds = []
            while (len(output_speeds) < max_speeds):
                speed = self._comp.read32(speed_reg)
                valid = speed & (1 << 31)
                speed &= (1 << 31) - 1
                if (valid == 0):
                    break
                output_speeds.append(self._conv_Bscn2Gbs(speed, sec_len, frequency))
                speed_reg += 4

            print("\"{}\"".format(self._name))
            print("Status:          {0:08x} ({1})".format(status, status_s))
            print("Section length:  {} clock cycles".format(sec_len))
            print("Interval length: {} sections".format(self._comp.read32(self._REG_INT_LEN)))
            print("Interval count:  {} intervals".format(max_speeds))
            print("Frequency:       {} MHz".format(frequency))
            print("Output speed:    {} Gb/s".format(output_speeds))
        except:
            print("{}: Error while reading configuration!".format(self._name))


    def configure(self, cfg):
        """Configure component"""

        try:
            frequency  = self._comp.read32(self._REG_FREQ)
            if (cfg["section_length"] >= frequency * 1_000_000):
                print("{}: Error - Section too long!".format(self._name))
                return

            self._comp.write32(self._REG_STATUS, self._SR_CONF_FLAG)
            self._comp.write32(self._REG_SEC_LEN, cfg["section_length"])
            self._comp.write32(self._REG_INT_LEN, cfg["interval_length"])

            max_speeds = self._comp.read32(self._REG_INT_CNT)
            available  = max_speeds
            speed_reg  = self._REG_SPEED
            for speed in cfg["output_speed"]:
                if (available == 0):
                    print("{0}: Insufficient number of speed regs in the design ({1})! Ignoring speeds over the limit...".format(self._name, max_speeds))
                    break
                self._comp.write32(speed_reg, self._conv_Gbs2Bscn(speed, cfg["section_length"], frequency))
                speed_reg += 4
                available -= 1
        except:
            print("{}: Error while writing configuration!".format(self._name))
        finally:
            self._comp.write32(self._REG_STATUS, 0)

    def start_shaping(self, ptr_reset=False):
        """Start traffic shaping"""

        if (ptr_reset):
            self._comp.write32(self._REG_STATUS, self._SR_PTR_RST_FLAG)
        self._comp.write32(self._REG_STATUS, self._SR_RUN_FLAG)

    def stop_shaping(self):
        """Stop traffic shaping"""

        self._comp.write32(self._REG_STATUS, 0)

