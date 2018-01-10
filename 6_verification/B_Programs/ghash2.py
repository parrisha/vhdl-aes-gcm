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
#h_in = getrandbits(128)
h_in = 0x73A23D80121DE2D5A850253FCF43120E
print "{:032X}".format(h_in)
y = 0L
r_in = 0xE1000000000000000000000000000000L


def ghash(x_in, y_in):
  #x_in = getrandbits(128)
  print "{:032X}".format(x_in)
  #This algorithm is taken from 
  # http://csrc.nist.gov/groups/ST/toolkit/BCM/documents/proposedmodes/gcm/gcm-spec.pdf
  # and operates with little-endian inputs and outputs.
  x = x_in
  h = h_in
  r = r_in

  #Xor input with previous output
  v = x ^ y_in;
  y = 0L;
  print "#DEBUG   {:X}".format(v)
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
  
  print "#DEBUG = {:X}".format(y)
  return y

y = ghash(0xD609B1F056637A0D46DF998D88E52E00, 0x0)
y = ghash(0xB2C2846512153524C0895E8100000000, y)
y = ghash(0x701AFA1CC039C0D765128A665DAB6924, y)
y = ghash(0x3899BF7318CCDC81C9931DA17FBE8EDD, y)
y = ghash(0x7D17CB8B4C26FC81E3284F2B7FBA713D, y)
y = ghash(0x00000000000000E00000000000000180, y)
print "{:032X}".format(y)
    
