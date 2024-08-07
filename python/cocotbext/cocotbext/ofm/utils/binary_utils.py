# binary_utils.py: Tools for working with binary numbers in Python
# Copyright (C) 2024 CESNET z. s. p. o.
# Author(s): Ondřej Schwarz <Ondrej.Schwarz@cesnet.cz>
#
# SPDX-License-Identifier: BSD-3-Clause

def int_to_bits(integer:int, lenght:int) -> list:
    result = list()
    
    for _ in range(lenght):
        result.insert(0, integer % 2)
        integer = integer >> 1
        
    return result
    
def bits_to_int(bits:list, num_of_bits:int, big_endian:bool=True) -> int:
    result = 0
    
    if big_endian:
        bits = bits[::-1]

    for i in range(num_of_bits):
        result += bits[i] << i
        
    return result

def not_bits(bits:list, length:int) -> list:
    for i in range(length):
        bits[i] = not(bits[i])
    return bits

def and_bits(bits1:list, bits2:list, length:int) -> list:
    result = list()
    
    for i in range(length):
        result.append(bits1[i] and bits2[i])
    
    return result

def or_bits(bits1:list, bits2:list, length:int) -> list:
    result = list()
    
    for i in range(length):
        result.append(bits1[i] or bits2[i])
    
    return result

def xor_bits(bits1:list, bits2:list, length:int) -> list:
    result = list()
    
    for i in range(length):
        result.append(bits1[i] ^ bits2[i])
    
    return result
