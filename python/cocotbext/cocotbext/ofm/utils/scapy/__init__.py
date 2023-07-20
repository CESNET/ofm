import sys

# disable warnings from Scapy
__stderr = sys.stderr
sys.stderr = None
from scapy.all import TCP, Ether, IP, raw
sys.stderr = __stderr
del __stderr


def s2b(pkt):
    return bytes(raw(pkt))
