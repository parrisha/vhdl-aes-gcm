--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity ghash_datapath2 is
   generic(
      block_size  : natural := 128;
      mult_depth  : natural := 32
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
end ghash_datapath2;

architecture dataflow of ghash_datapath2 is

type block_array is array (integer range <>) of std_logic_vector(block_size-1 downto 0);

--signal y : std_logic_vector(block_size-1 downto 0);
--signal y_valid : std_logic;
signal xor_result  : std_logic_vector(block_size-1 downto 0);
signal gf_mult_out : std_logic_vector(block_size-1 downto 0);

signal mult_and     : block_array(mult_depth downto 0);
signal mult_xor_1   : block_array(mult_depth downto 0);
signal mult_xor_2   : block_array(mult_depth downto 0);
signal h_replicated : block_array(mult_depth downto 0);

signal h_rev : std_logic_vector(block_size-1 downto 0);
signal x_rev : std_logic_vector(block_size-1 downto 0);
signal y_rev : std_logic_vector(block_size-1 downto 0);

signal x_reg : std_logic_vector(block_size-1 downto 0);
signal y_reg : std_logic_vector(block_size-1 downto 0);
signal z_reg : std_logic_vector(block_size-1 downto 0);
signal x_in  : std_logic_vector(block_size-1 downto 0);
signal z_in  : std_logic_vector(block_size-1 downto 0);
signal z_en  : std_logic;
signal h_32  : std_logic_vector(mult_depth-1 downto 0);

signal ghash_valid_in    : std_logic_vector(3 downto 0);
signal ghash_valid_reg   : std_logic_vector(3 downto 0);
signal ghash_valid_shift : std_logic;

signal mult_acc_done     : std_logic;
signal final_out_valid   : std_logic;
begin

--I think I need to swap the bit-order of H, V and Y_out
bit_reverse : for i in 0 to block_size-1 generate
   x_rev(i) <= x_i((block_size-1)-i);
   y_rev(i) <= y_reg((block_size-1)-i);
   h_rev(i) <= h_i((block_size-1)-i);
end generate;

--Register incoming data one cycle to line up with new 4 cycle valid counter
x_in <= x_rev xor y_reg;

x_register : register_async
generic map (
   n => block_size
)
port map (
   d_i           => x_in,
   en_i          => x_valid_i,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => x_reg
);

--Create a register that will be "active" for four clock cycles
ghash_valid_in <= (others => '1') when x_valid_i = '1' else (ghash_valid_reg((block_size / mult_depth)-2 downto 0) & '0');

ghash_valid_shift_register : register_async
generic map (
   n => (block_size / mult_depth)
)
port map (
   d_i           => ghash_valid_in,
   en_i          => z_en,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => ghash_valid_reg
);

ghash_valid_shift <= ghash_valid_reg((block_size / mult_depth)-1);

--Mux to select which part of H to use in the 128x32 multiply
with ghash_valid_reg select
   h_32 <= h_rev(127 downto 96) when "1111",
           h_rev( 95 downto 64) when "1110",
           h_rev( 63 downto 32) when "1100",
           h_rev( 31 downto  0) when others;

--register to store intermediate z value
z_in <= (others => '0') when x_valid_i = '1' else (gf_mult_out);
z_en <= (ghash_valid_shift or x_valid_i);

z_register : register_async
generic map (
   n => block_size
)
port map (
   d_i           => z_in,
   en_i          => z_en,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => z_reg
);

xor_result <= x_reg;
mult_xor_2(0)(block_size-1 downto 7) <= z_reg(block_size-1 downto 7);
mult_xor_2(0)(5 downto 2)            <= z_reg(5 downto 2);
mult_xor_2(0)(0) <= z_reg(0) xor z_reg(block_size-1);
mult_xor_2(0)(1) <= z_reg(1) xor z_reg(block_size-1);
mult_xor_2(0)(6) <= z_reg(6) xor z_reg(block_size-1);

--Figure 6 from Source [8]
GF_MULT : for i in 1 to mult_depth generate
   h_replicated(i) <= (others => h_32(mult_depth-i));
   mult_and(i)     <= xor_result and h_replicated(i);
   mult_xor_1(i)   <= mult_and(i) xor (mult_xor_2(i-1)(block_size-2 downto 0) & mult_xor_2(i-1)(block_size-1));
   
   mult_xor_2(i)(block_size-1 downto 7) <= mult_xor_1(i)(block_size-1 downto 7);
   mult_xor_2(i)(5 downto 2)            <= mult_xor_1(i)(5 downto 2);
   mult_xor_2(i)(0) <= mult_xor_1(i)(0) xor mult_xor_1(i)(block_size-1);
   mult_xor_2(i)(1) <= mult_xor_1(i)(1) xor mult_xor_1(i)(block_size-1);
   mult_xor_2(i)(6) <= mult_xor_1(i)(6) xor mult_xor_1(i)(block_size-1);
   
end generate;

gf_mult_out <= mult_xor_1(mult_depth);


--After 4 multiply-accumulate cycles, write the output to the Y register
mult_acc_done <= '1' when (ghash_valid_reg = "1000") else '0';

--y_in <= z_reg xor gf_mult_out;

y_register : register_async
generic map (
   n => block_size
)
port map (
   d_i           => z_in,
   en_i          => mult_acc_done,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => y_reg
);

y_o <= y_rev;

--When the multiply-accumulate is done, let the controller know we could input more data
-- (Only applies to AAD.  MSG data is limited by AES latency)
ghash_done_o <= mult_acc_done;

--After processing the last input, generate an output valid
final_out_valid <= x_last_input and mult_acc_done;

y_valid_register : register_async_1bit
port map (
   d_i           => final_out_valid,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => y_valid_o
);

end architecture dataflow;
