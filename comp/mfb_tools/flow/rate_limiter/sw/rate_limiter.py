############################################################
# rate_limiter.py: Rate Limiter class
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Tomas Hak <xhakto01@vut.cz>
############################################################

import nfb


class RateLimiter:
    """Rate Limiter component class

    This class mediates the HW component address space and communication protocol.
    """

    # MI ADDRESS SPACE
    STATUS  = 0x00
    SEC_LEN = 0x04
    INT_LEN = 0x08
    INT_CNT = 0x0c
    FREQ    = 0x10
    SPEED   = 0x14

    # STATUS REGISTER FLAGS
    SR_IDLE_FLAG    = 0x01
    SR_CONF_FLAG    = 0x02
    SR_RUN_FLAG     = 0x04
    SR_PTR_RST_FLAG = 0x08

    def __init__(self, dev, node):
        """Constructor"""

        try:
            self.comp = dev.comp_open(node)
            self.name = node.path + '/' + node.name
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

        return self.comp.read32(self.FREQ) * 1_000_000

    def print_cfg(self):
        """Print current configuration"""

        try:
            status     = self.comp.read32(self.STATUS)
            sec_len    = self.comp.read32(self.SEC_LEN)
            max_speeds = self.comp.read32(self.INT_CNT)
            frequency  = self.comp.read32(self.FREQ)

            status_s     = "Idle"
            if (status == self.SR_CONF_FLAG):
                status_s = "Configuration"
            elif (status == self.SR_RUN_FLAG):
                status_s = "Running traffic shaping"

            speed_reg     = self.SPEED
            output_speeds = []
            while (len(output_speeds) < max_speeds):
                speed = self.comp.read32(speed_reg)
                valid = speed & (1 << 31)
                speed &= (1 << 31) - 1
                if (valid == 0):
                    break
                output_speeds.append(self._conv_Bscn2Gbs(speed, sec_len, frequency))
                speed_reg += 4

            print("\"{}\"".format(self.name))
            print("Status:          {0:08x} ({1})".format(status, status_s))
            print("Section length:  {} clock cycles".format(sec_len))
            print("Interval length: {} sections".format(self.comp.read32(self.INT_LEN)))
            print("Interval count:  {} intervals".format(max_speeds))
            print("Frequency:       {} MHz".format(frequency))
            print("Output speed:    {} Gb/s".format(output_speeds))
        except:
            print("{}: Error while reading configuration!".format(self.name))


    def configure(self, cfg):
        """Configure component"""

        try:
            frequency  = self.comp.read32(self.FREQ)
            if (cfg["section_length"] >= frequency * 1_000_000):
                print("{}: Error - Section too long!".format(self.name))
                return

            self.comp.write32(self.STATUS, self.SR_CONF_FLAG)
            self.comp.write32(self.SEC_LEN, cfg["section_length"])
            self.comp.write32(self.INT_LEN, cfg["interval_length"])

            max_speeds = self.comp.read32(self.INT_CNT)
            available  = max_speeds
            speed_reg  = self.SPEED
            for speed in cfg["output_speed"]:
                if (available == 0):
                    print("{0}: Insufficient number of speed regs in the design ({1})! Ignoring speeds over the limit...".format(self.name, max_speeds))
                    break
                self.comp.write32(speed_reg, self._conv_Gbs2Bscn(speed, cfg["section_length"], frequency))
                speed_reg += 4
                available -= 1
        except:
            print("{}: Error while writing configuration!".format(self.name))
        finally:
            self.comp.write32(self.STATUS, 0)

    def start_shaping(self, ptr_reset=False):
        """Start traffic shaping"""

        if (ptr_reset):
            self.comp.write32(self.STATUS, self.SR_PTR_RST_FLAG)
        self.comp.write32(self.STATUS, self.SR_RUN_FLAG)

    def stop_shaping(self):
        """Stop traffic shaping"""

        self.comp.write32(self.STATUS, 0)

