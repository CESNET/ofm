############################################################
# speed_meter.py: Speed Meter component class
# Copyright (C) 2022 CESNET z. s. p. o.
# Author(s): Tomas Hak <xhakto01@vut.cz>
############################################################

import nfb


class SpeedMeter(nfb.BaseComp):
    """Speed Meter component class

    This class mediates the HW component address space and communication protocol.
    """

    # DevTree compatible string
    DT_COMPATIBLE = "cesnet,ofm,speed_meter"

    # MI ADDRESS SPACE
    _REG_TICKS  = 0x00
    _REG_STATUS = 0x04
    _REG_BYTES  = 0x08
    _REG_CLEAR  = 0x0c

    # STATUS REGISTER FIELDS
    _SR_DONE_FLAG = 0x00

    def __init__(self, **kwargs):
        """Constructor"""

        try:
            super().__init__(**kwargs)
            self._name = "Speed Meter"
            if "index" in kwargs:
                self._name += " " + str(kwargs.get("index"))
        except:
            print("Error while opening Speed Meter component!")

    def test_complete(self):
        """Check if speed measurement is complete"""

        return self._comp.get_bit(self._REG_STATUS, self._SR_DONE_FLAG)

    def get_data(self):
        """Retrieve measured data"""

        return self._comp.read32(self._REG_BYTES), self._comp.read32(self._REG_TICKS)

    def clear_data(self):
        """Reset measurement statistics"""

        self._comp.write32(self._REG_CLEAR, 0x1)

