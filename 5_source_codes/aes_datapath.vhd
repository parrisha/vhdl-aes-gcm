--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity aes_datapath is
   generic(
      block_size  : natural := 128;
      key_size    : natural := 128;
      num_rounds  : natural := 10
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      cipher_i       : in  std_logic_vector(block_size-1 downto 0);
      cipher_valid_i : in  std_logic;
      cipher_o       : out std_logic_vector(block_size-1 downto 0);
      cipher_valid_o : out std_logic;
      key_i          : in  std_logic_vector(key_size-1 downto 0);
      key_valid_i    : in  std_logic
   );
end aes_datapath;

architecture dataflow of aes_datapath is

--4 bits needed to count to 10
signal num_rounds_plus1 : std_logic_vector(3 downto 0);
signal num_rounds_reg   : std_logic_vector(num_rounds downto 0);
signal num_rounds_eq    : std_logic;
signal num_rounds_shift : std_logic_vector(num_rounds downto 0);
signal start_cipher     : std_logic;
signal cipher_reg       : std_logic_vector(block_size-1 downto 0);
signal add_first_key    : std_logic_vector(block_size-1 downto 0);

signal aes_round_out_reg : std_logic_vector(block_size-1 downto 0);
signal aes_round_in      : std_logic_vector(block_size-1 downto 0);
signal aes_round_out     : std_logic_vector(block_size-1 downto 0);

signal keygen_data       : std_logic_vector(block_size-1 downto 0);
signal keygen_data_le    : std_logic_vector(block_size-1 downto 0);

begin

----Generate a round counter and comparator
--num_rounds_plus1 <= std_logic_vector(unsigned(num_rounds_reg) + to_unsigned(1, 4));
--
----Let the counter free-run, reset when a valid word comes in
--num_rounds_register : register_async_clear
--generic map (
--   n => 4
--)
--port map (
--   d_i           => num_rounds_plus1,
--   clear_i       => cipher_valid_i
--   en_i          => '1',
--   reset_async_i => rst_i,
--   clk_i         => clk_i,
--   q_o           => num_rounds_reg
--);

----Let the counter free-run, reset when a valid word comes in
--num_rounds_counter : counter
--generic map (
--   n => 4
--)
--port(
--   d_i           => (others => '0'),
--   en_i          => '1',
--   ld_i          => cipher_valid_i,
--   reset_async_i => rst_i,
--   clk_i         => clk_i,
--   q_o           => num_rounds_reg
--);

--Generate a shift register that shifts the input valid all the way to the output valid
num_rounds_shift <= num_rounds_reg(num_rounds-1 downto 0) & cipher_valid_i;

rounds_shift_register : register_async
generic map (
   n => (num_rounds+1)
)
port map (
   d_i           => num_rounds_shift,
   en_i          => '1',
   reset_async_i => '0', --Attempt to map this into an SRL
   clk_i         => clk_i,
   q_o           => num_rounds_reg
);

cipher_valid_o <= num_rounds_reg(num_rounds);
num_rounds_eq  <= num_rounds_reg(num_rounds-1);
start_cipher   <= num_rounds_reg(0);

--num_rounds_eq <= '1' when (unsigned(num_rounds_reg) = (num_rounds-1)) else '0';
add_first_key  <= cipher_i xor keygen_data;

--Register cipher_i so it lines up with the first set of round keys
cipher_i_register : register_async
generic map (
   n => block_size
)
port map (
   d_i           => add_first_key,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => cipher_reg
);

--Select either the incoming data or the previous rounds output as input
aes_round_in <= cipher_reg when start_cipher = '1' else aes_round_out_reg;

--Instantiate one round of AES
aes : entity work.aes_round(basic)
port map ( 
	last_round	=> num_rounds_eq,
	input 		=> aes_round_in,
	key			=> keygen_data,
   output 		=> aes_round_out
);

--Register the round output
aes_round_register : register_async
generic map (
   n => block_size
)
port map (
   d_i           => aes_round_out,
   en_i          => '1',
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => aes_round_out_reg
);

--Instantiate AES KeyGen
--Always active, outputs 4 round keys (128-bits) every clock cycle
--Generates round keys on demand rather than storing in a block ram
--Sync_i returns to original key values, 1 clock cycle later the first valid round keys are output
keygen : aes_keygen
generic map(
   key_size   => key_size
)
port map (
   clk_i         => clk_i,
   rst_i         => rst_i,
   key_i         => key_i,
   key_valid_i   => key_valid_i,
   sync_i        => cipher_valid_i,
   round_key_o   => keygen_data
);


cipher_o <= aes_round_out_reg;
--Since we computer all of this with bits 0->127, flip them back to 127->0
--keygen_le : for i in 0 to block_size-1 generate
--   cipher_o(i) <= aes_round_out_reg((block_size-1)-i);
--end generate;


end architecture dataflow;