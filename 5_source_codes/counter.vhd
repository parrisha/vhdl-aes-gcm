--ECE 545 HW 6
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--When LD is high, writes D_i to an internal register
--Else when EN is high, increments the internal register value

entity counter is
   generic(
      n : natural := 8
   );
   port(
      d_i           : in  std_logic_vector(n-1 downto 0);
      en_i          : in  std_logic;
      ld_i          : in  std_logic;
      reset_async_i : in  std_logic;
      clk_i         : in  std_logic;
      q_o           : out std_logic_vector(n-1 downto 0)
   );
end counter;

architecture behavioral of counter is

signal q : std_logic_vector(n-1 downto 0);

begin
   process (reset_async_i, clk_i)
   begin
      if (reset_async_i = '1') then
         q <= (others => '0');
      elsif rising_edge(clk_i) then
         if (ld_i = '1') then
            q <= d_i;
         elsif (en_i = '1') then
            q <= std_logic_vector(unsigned(q) + to_unsigned(1, n));
         end if;
      end if;
   end process;

   q_o <= q;
   
end behavioral;