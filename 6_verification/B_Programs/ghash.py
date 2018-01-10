#!/usr/local/bin/python2.7

from random import *;

def swap_endian(n):
  swapped = 0x0L
  for i in range(0, 128):
    swapped = swapped << 1;
    if (n & (0x1L << i) != 0x0L):
      swapped = swapped | 0x1L
  return swapped

seed(0xDEADBEEF);

v = 0L
h_in = getrandbits(128)
print "{:032X}".format(h_in)
y = 0L
r_in = 0x00000000000000000000000000000087L


for i in range(0, 128):
  x_in = getrandbits(128)
  print "{:032X}".format(x_in)
  #This algorithm is taken from 
  # http://csrc.nist.gov/groups/ST/toolkit/BCM/documents/proposedmodes/gcm/gcm-spec.pdf
  # and operates with little-endian inputs and outputs.
  x = swap_endian(x_in)
  h = swap_endian(h_in)
  r = swap_endian(r_in)

  #Xor input with previous output
  v = x ^ y;
  y = 0L;
  print "#DEBUG   {:X}".format(swap_endian(v))
  print "#DEBUG x {:X}".format(h_in)
  
  #Perform GF-128 Multipication
  for j in range(0, 128):
    if (h & (0x1L << (127-j)) != 0x0L):
      y = y ^ v
    if ((v & 0x1L) != 0x0L):
      v = v >> 1;
      v = v ^ r;
    else:
      v = v >> 1;
  
  print "#DEBUG = {:X}".format(swap_endian(y))
  
print "{:032X}".format(swap_endian(y))
    
