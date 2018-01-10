--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;
  
entity ghash_datapath_tb is
end ghash_datapath_tb;

architecture  behavior of ghash_datapath_tb is 

constant clock_period_tb : time := 20 ns; --50 MHz clock

file ghashTestVectorFile : text is in "ghash_datapath_test_vector2.txt";

component ghash_datapath
   generic(
      block_size  : natural
   );
   port(
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;
      x_i            : in  std_logic_vector(block_size-1 downto 0);
      x_valid_i      : in  std_logic;
      x_last_input   : in  std_logic;
      h_i            : in  std_logic_vector(block_size-1 downto 0);
      y_o            : out std_logic_vector(block_size-1 downto 0);
      y_valid_o      : out std_logic
   );
end component;

signal clock_tb : std_logic;
signal rst_i : std_logic;
      -- Data Interface
signal ghash_in            : std_logic_vector(127 downto 0);
signal ghash_in_valid      : std_logic;
signal ghash_in_last_input : std_logic;
signal ghash_h             : std_logic_vector(127 downto 0);
signal ghash_out           : std_logic_vector(127 downto 0);
signal ghash_out_file      : std_logic_vector(127 downto 0);
signal ghash_out_valid     : std_logic;

begin

--Generate clock
clk_generator : process
begin
   clock_tb <= '0';
   wait for clock_period_tb/2;
   clock_tb <= '1';
   wait for clock_period_tb/2;
end process;


--Push in 128 inputs
DutInput : process
   variable vectorLine : line;
   variable vectorValid : boolean;
   variable fileValue : std_logic_vector(127 downto 0);
begin

   --Reset dut before applying any input
   rst_i   <= '1';
   wait for clock_period_tb * 5;
   rst_i   <= '0';

   ghash_in_last_input <= '0';
   wait until rising_edge(clock_tb);
   
   --Read H from file (first non-comment line)
   vectorValid := false;
   while not vectorValid loop
      readline(ghashTestVectorFile, vectorLine);
      hread(vectorLine, fileValue, good => vectorValid);
   end loop;
   
   ghash_h <= fileValue;
   
   --Read input block, 128-bits per line
   for i in 0 to 127 loop
      wait until rising_edge(clock_tb);
      vectorValid := false;
      while not vectorValid loop
         readline(ghashTestVectorFile, vectorLine);
         hread(vectorLine, fileValue, good => vectorValid);
      end loop;
      
      ghash_in       <= fileValue;
      ghash_in_valid <= '1';
      if i = 127 then
         ghash_in_last_input <= '1';
      end if;
   end loop;
   
   wait until rising_edge(clock_tb);
   ghash_in_valid      <= '0';
   ghash_in_last_input <= '0';

   --Read GHASH output value from file, see if they match
   vectorValid := false;
   while not vectorValid loop
      readline(ghashTestVectorFile, vectorLine);
      hread(vectorLine, fileValue, good => vectorValid);
   end loop;
   
   ghash_out_file <= fileValue;
   
   wait for 3 ns;
   assert ghash_out_file = ghash_out
      report "Error found, outputs do not match"
      severity error;
      
   wait;
end process;


-- 1 instantiation of GHASH
   DUT : ghash_datapath
   generic map (
      block_size  => 128
   )
   port map (
      clk_i   => clock_tb,
      rst_i => rst_i,
      -- Data Interface
      x_i          => ghash_in,
      x_valid_i    => ghash_in_valid,
      x_last_input => ghash_in_last_input,
      h_i          => ghash_h, 
      y_o          => ghash_out,
      y_valid_o    => ghash_out_valid
   );
   
   
end architecture behavior;