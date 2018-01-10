from random import *;

def swap_endian(n):
  swapped = 0x0L
  for i in range(0, 128):
    swapped = swapped << 1;
    if (n & (0x1L << i) != 0x0L):
      swapped = swapped | 0x1L
  return swapped

def ghash(x_in, h_in):
    r_in = 0x00000000000000000000000000000087L
    if not hasattr(ghash, "y_prev"):
        ghash.y_prev = 0
    x = swap_endian(x_in)
    h = swap_endian(h_in)
    r = swap_endian(r_in)
    
    #Xor input with previous output
    v = x ^ ghash.y_prev;
    y = 0L
    
    #Perform GF-128 Multipication
    for j in range(0, 128):
        if (h & (0x1L << (127-j)) != 0x0L):
            y = y ^ v
        if ((v & 0x1L) != 0x0L):
            v = v >> 1;
            v = v ^ r;
        else:
            v = v >> 1;
            
    ghash.y_prev = y
    return swap_endian(y)
    
    
def cipher(x):
    if not hasattr(cipher, "key"):
        cipher.key = x
        print "#K {:032X}".format(cipher.key)
    return x ^ 0xFFFFFFFF00000000FFFFFFFF00000000L
    
    
def gctr(icb, load_icb, x):
    if (load_icb == 1):
        gctr.cb = icb
    else:
        gctr.cb = gctr.cb + 1
        
    y = cipher(gctr.cb)
    
    #print "#Y {:032X}".format(gctr.cb)
    
    return x ^ y
    
    
#Start of program!
seed(0xDEADBEEF);

key = getrandbits(128)
#Write key to file
print "K {:032X}".format(key)

#Apply key to datapath
h = cipher(key)

print "#H {:032X}".format(h)

iv = getrandbits(96)
#Write IV to file
print "I {:024X}".format(iv)

#compute J0
j0 = (iv << 32) | (0x1)

#8 AAD Words
print "A 8"
for i in range(0, 8):
    aad = getrandbits(128)
    print "{:032X}".format(aad)
    
    #Apply each AAD to ghash
    ghash(aad, h)
    
#64 P Words
print "P 64"
#prime gctr
gctr(j0, 1, 0)
for i in range(0, 64):
    msg = getrandbits(128)
    print "{:032X}".format(msg)
    
    #GCTR P and then GHASH result
    c = gctr(0, 0,  msg)
    print "{:032X}".format(c)
    ghash(c, h)

#GHASH the length word
y = ghash(0x00000000000000080000000000000040, h);
#Almost Done!
tag_128 = gctr(j0, 1, y)

tag_96 = tag_128 >> 32
print "T {:024X}".format(tag_96)
