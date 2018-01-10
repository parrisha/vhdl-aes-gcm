--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;
use work.aes_pkg.all;

entity aes_keygen is
   generic (
      key_size    : natural := 128
   );
   port (
      clk_i         : in  std_logic;
      rst_i         : in  std_logic;
      key_i         : in  std_logic_vector(key_size-1 downto 0);
      key_valid_i   : in  std_logic;
      sync_i        : in  std_logic;
      round_key_o   : out std_logic_vector(key_size-1 downto 0)
   );
end aes_keygen;

architecture dataflow of aes_keygen is

signal w0 : std_logic_vector(31 downto 0);
signal w1 : std_logic_vector(31 downto 0);
signal w2 : std_logic_vector(31 downto 0);
signal w3 : std_logic_vector(31 downto 0);

signal w0_next : std_logic_vector(31 downto 0);
signal w1_next : std_logic_vector(31 downto 0);
signal w2_next : std_logic_vector(31 downto 0);
signal w3_next : std_logic_vector(31 downto 0);

signal w0_reg : std_logic_vector(31 downto 0);
signal w1_reg : std_logic_vector(31 downto 0);
signal w2_reg : std_logic_vector(31 downto 0);
signal w3_reg : std_logic_vector(31 downto 0);

signal key_reg : std_logic_vector(127 downto 0);
signal key_rev :  std_logic_vector(127 downto 0);

signal after_subbyte : std_logic_vector(31 downto 0);
signal mix_column    : std_logic_vector(31 downto 0);
signal rcon_xor      : std_logic_vector(31 downto 0);
signal rcon_next     : std_logic_vector(7 downto 0);
signal rcon_reg      : std_logic_vector(7 downto 0);
signal rcon_x2       : std_logic_vector(7 downto 0);

begin
--Note
-- The AES spec defines the leftmost bit as bit0
-- So reverse the incoming key order
-- This also makes it easier to verify operation against the key expansion example
keygen_reverse : for i in 0 to key_size-1 generate
   key_rev(i) <= key_i((key_size-1)-i);
end generate;

--Store the key so it can be reused for each sync
key_register : register_async
generic map (
   n => key_size
)
port map (
   d_i           => key_i, --key_rev,
   en_i          => key_valid_i,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => key_reg
);

--One 8 bit register stores Rcon
--The upper 24 bits of Rcon are always 0
--The lower 8  bits of Rcon come from the register
--Reset rcon to 2 when syncing
rcon_register : register_async
generic map (
   n => 8
)
port map (
   d_i           => rcon_next,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => rcon_reg
);

--After syncing, rcon is multiplied by 2 in GF^8 every cycle
rcon_gf_x2 : entity work.aes_mul(aes_mulx02)
port map ( 
	input   => rcon_reg,
   output  => rcon_x2
);

rcon_next <= x"01" when sync_i = '1' else rcon_x2;

--4 32-bit registers stores w0, w1, w2, w3
w0_register : register_async
generic map (
   n => 32
)
port map (
   d_i           => w0,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => w0_reg
);

w1_register : register_async
generic map (
   n => 32
)
port map (
   d_i           => w1,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => w1_reg
);

w2_register : register_async
generic map (
   n => 32
)
port map (
   d_i           => w2,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => w2_reg
);

w3_register : register_async
generic map (
   n => 32
)
port map (
   d_i           => w3,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => w3_reg
);

--Write either from the key when syncing or from the logic
w3 <= key_reg( 31 downto  0) when sync_i = '1' else w3_next;
w2 <= key_reg( 63 downto 32) when sync_i = '1' else w2_next;
w1 <= key_reg( 95 downto 64) when sync_i = '1' else w1_next;
w0 <= key_reg(127 downto 96) when sync_i = '1' else w0_next;

--Based on the previous round_keys (w*_reg), compute the next round keys
sbox_gen: for i in 0 to 3 generate
   sbox	: aes_sbox
   generic map (
      rom_style => 0
   )
   port map (	 
      input  => w3_reg(8*(i+1)-1 downto 8*i), 
      output => after_subbyte(8*(i+1)-1 downto 8*i)
   );	
end generate;

mix_column <= after_subbyte(23 downto 0) & after_subbyte(31 downto 24);
rcon_xor   <= mix_column xor (rcon_reg & x"000000");
w3_next    <= w2_next  xor w3_reg;
w2_next    <= w1_next  xor w2_reg;
w1_next    <= w0_next  xor w1_reg;
w0_next    <= rcon_xor xor w0_reg;

--Key output is equal to the pending value at register
round_key_o <= w0 & w1 & w2 & w3;
end architecture dataflow;