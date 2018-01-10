--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity ghash_datapath is
   generic(
      block_size  : natural := 128
   );
   port(
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      x_i            : in  std_logic_vector(block_size-1 downto 0);
      x_valid_i      : in  std_logic;
      x_last_input   : in  std_logic;
      ghash_done_o   : out std_logic;
      h_i            : in  std_logic_vector(block_size-1 downto 0);
      y_o            : out std_logic_vector(block_size-1 downto 0);
      y_valid_o      : out std_logic
   );
end ghash_datapath;

architecture dataflow of ghash_datapath is

constant XOR_2_PATTERN : std_logic_vector(block_size-1 downto 0) := x"00000000000000000000000000000043";
type block_array is array (integer range <>) of std_logic_vector(block_size-1 downto 0);

signal y : std_logic_vector(block_size-1 downto 0);
signal y_valid : std_logic;
signal xor_result  : std_logic_vector(block_size-1 downto 0);
signal gf_mult_out : std_logic_vector(block_size-1 downto 0);

signal mult_and     : block_array(block_size downto 0);
signal mult_xor_1   : block_array(block_size downto 0);
signal mult_xor_2   : block_array(block_size downto 0);
signal h_replicated : block_array(block_size downto 0);

signal h_rev : std_logic_vector(block_size-1 downto 0);
signal x_rev : std_logic_vector(block_size-1 downto 0);
signal y_rev : std_logic_vector(block_size-1 downto 0);

begin

--I think I need to swap the bit-order of H, V and Y_out
bit_reverse : for i in 0 to block_size-1 generate
   h_rev(i) <= h_i((block_size-1)-i);
   x_rev(i) <= x_i((block_size-1)-i);
   y_rev(i) <= y((block_size-1)-i);
end generate;

--register to store previous Y value
y_register : register_async
generic map (
   n => block_size
)
port map (
   d_i           => gf_mult_out,
   en_i          => x_valid_i,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => y
);

xor_result <= x_rev xor y;
mult_xor_2(0) <= std_logic_vector(to_unsigned(0, 128));

--Figure 6 from Source [8]
GF_MULT : for i in 1 to block_size generate
   h_replicated(i) <= (others => h_rev(block_size-i));
   mult_and(i)     <= xor_result and h_replicated(i);
   mult_xor_1(i)   <= mult_and(i) xor (mult_xor_2(i-1)(block_size-2 downto 0) & mult_xor_2(i-1)(block_size-1));
   
  mult_xor_2(i)(block_size-1 downto 7) <= mult_xor_1(i)(block_size-1 downto 7);
  mult_xor_2(i)(5 downto 2)            <= mult_xor_1(i)(5 downto 2);
  mult_xor_2(i)(0) <= mult_xor_1(i)(0) xor mult_xor_1(i)(block_size-1);
  mult_xor_2(i)(1) <= mult_xor_1(i)(1) xor mult_xor_1(i)(block_size-1);
  mult_xor_2(i)(6) <= mult_xor_1(i)(6) xor mult_xor_1(i)(block_size-1);
   
   --XOR_2 : for j in 0 to block_size-1 generate
   --   GEN_XOR : if (XOR_2_PATTERN(j) = '1') generate
   --      mult_xor_2(i)(j) <= mult_xor_1(i)(j) xor mult_xor_1(i)(block_size-1);
   --   end generate;
   --   
   --   NO_XOR : if (XOR_2_PATTERN(j) = '0') generate
   --      mult_xor_2(i)(j) <= mult_xor_1(i)(j);
   --   end generate;
   --end generate;
end generate;

gf_mult_out <= mult_xor_1(block_size);

y_o <= y_rev;

ghash_done_o <= x_valid_i;

--Delay the valid output by the 1-clock cycle it takes to process data
y_valid <= x_valid_i and x_last_input;

y_valid_register : register_async_1bit
port map (
   d_i           => y_valid,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => y_valid_o
);

end architecture dataflow;
