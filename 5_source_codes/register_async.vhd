--ECE 545 HW 6
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;

entity register_async is
   generic(
      n : natural := 8
   );
   port(
      d_i           : in  std_logic_vector(n-1 downto 0);
      en_i          : in  std_logic;
      reset_async_i : in  std_logic;
      clk_i         : in  std_logic;
      q_o           : out std_logic_vector(n-1 downto 0)
   );
end register_async;


architecture behavioral of register_async is

begin
   process (reset_async_i, clk_i)
   begin
      if (reset_async_i = '1') then
         q_o <= (others => '0');
      elsif rising_edge(clk_i) then
         if (en_i = '1') then
            q_o <= d_i;
         end if;
      end if;
   end process;

end behavioral;