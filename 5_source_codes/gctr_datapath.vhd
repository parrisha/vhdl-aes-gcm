--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity gctr_datapath is
   generic(
      block_size  : natural := 128;
      icb_size    : natural := 96
   );
   port(
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      icb_i          : in  std_logic_vector(icb_size-1 downto 0);
      load_icb_i     : in  std_logic;
      x_i            : in  std_logic_vector(block_size-1 downto 0);
      x_valid_i      : in  std_logic;
      y_o            : out std_logic_vector(block_size-1 downto 0);
      y_valid_o      : out std_logic;
      cipher_o       : out std_logic_vector(block_size-1 downto 0);
      cipher_valid_o : out std_logic;
      cipher_i       : in  std_logic_vector(block_size-1 downto 0);
      cipher_valid_i : in  std_logic
   );
end gctr_datapath;

architecture dataflow of gctr_datapath is

signal cb_mux : std_logic_vector(icb_size-1 downto 0);
signal cb_inc : std_logic_vector(icb_size-1 downto 0);
signal cb_valid : std_logic;
signal cb_reg : std_logic_vector(icb_size-1 downto 0);
signal cipher_valid : std_logic;

begin

--Select either the initial counter block or the incrementing result
cb_mux <= icb_i when load_icb_i = '1' else cb_inc;

--Inc32
cb_inc <= cb_reg(icb_size-1 downto 32) & std_logic_vector(unsigned(cb_reg(31 downto 0)) + to_unsigned(1, 32));

--Write to the register when a new value is loaded or the cipher was just started with previous value
cb_valid <= load_icb_i or x_valid_i;

--register to store Incrementing counter block
cb_register : register_async
generic map (
   n => icb_size
)
port map (
   d_i           => cb_mux,
   en_i          => cb_valid,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => cb_reg
);

cipher_valid_o <= x_valid_i;
cipher_o(icb_size-1 downto 0)          <= cb_reg;
cipher_o(block_size-1 downto icb_size) <= (others => '0');

--The output is xor of cipher result and input
y_o <= x_i xor cipher_i;
--That output is valid when the cipher result is valid
y_valid_o <= cipher_valid_i;


end dataflow;

