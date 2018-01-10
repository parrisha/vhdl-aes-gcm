--ECE 545 HW 6
--Aaron Joe Parrish

--Create a special version of register_async that accepts std_logic as input/output
library ieee;
use ieee.std_logic_1164.all;

entity register_async_1bit is
   port(
      d_i           : in  std_logic;
      en_i          : in  std_logic;
      reset_async_i : in  std_logic;
      clk_i         : in  std_logic;
      q_o           : out std_logic
   );
end register_async_1bit;


architecture behavioral of register_async_1bit is

begin
   process (reset_async_i, clk_i)
   begin
      if (reset_async_i = '1') then
         q_o <= '0';
      elsif rising_edge(clk_i) then
         if (en_i = '1') then
            q_o <= d_i;
         end if;
      end if;
   end process;

end behavioral;