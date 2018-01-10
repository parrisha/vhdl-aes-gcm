--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.aes_gcm_pkg.all;
  
entity aes_gcm_top_tb is
end aes_gcm_top_tb;

architecture  behavior of aes_gcm_top_tb is 

constant clock_period_tb : time := 20 ns; --50 MHz clock

file aesgcmTestVectorFile : text is in "aesgcm_test_vector1.txt";

signal clock_tb : std_logic;
signal rst_i : std_logic;

signal pdi_ready   : std_logic;
signal pdi_data    : std_logic_vector(127 downto 0);
signal pdi_read    : std_logic;
signal sdi_ready   : std_logic;
signal sdi_data    : std_logic_vector(127 downto 0);
signal sdi_read    : std_logic;
signal do            : std_logic_vector(127 downto 0);
signal do_ready      : std_logic;
signal do_write      : std_logic;
signal error         : std_logic;
signal ecode         : std_logic_vector(7 downto 0);

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
   variable testLine : line;
   variable vectorValid : boolean;
   variable fileValue : std_logic_vector(127 downto 0);
begin
   --Reset dut before applying any input
   rst_i   <= '1';
   wait for clock_period_tb * 5;
   rst_i   <= '0';
   
   --All Data is stored in the File exactly as it should be applied to the datapath
   --The first 3 words are written in over secret interface
   --The rest of the words are written in over public interface
   wait until rising_edge(clock_tb);
   for i in 1 to 3 loop
      readline(aesgcmTestVectorFile, vectorLine);
      hread(vectorLine, fileValue, good => vectorValid);
      
      sdi_data <= fileValue;
      sdi_ready <= '1';
      wait until falling_edge(clock_tb);
      
      while sdi_read /= '1' loop
         wait until falling_edge(clock_tb);
      end loop;
      
      sdi_ready <= '0';
   end loop;
   
   while not endfile(aesgcmTestVectorFile) loop
      readline(aesgcmTestVectorFile, vectorLine);
      hread(vectorLine, fileValue, good => vectorValid);
      
      pdi_data <= fileValue;
      pdi_ready <= '1';
      wait until falling_edge(clock_tb);
      
      while pdi_read /= '1' loop
         wait until falling_edge(clock_tb);
      end loop;
      
      pdi_ready <= '0';
   end loop;
   
   wait;
end process;

DutOutput : process
   variable msgLine : line;
   variable msgOut  : std_logic_vector(127 downto 0);
begin 
   --Wait for some data to be output from the datapath, could be C or Tag
   wait until rising_edge(clock_tb);
   if do_write = '1' then
      write(msgLine, "DO: ");
      hwrite(msgLine, do);
      writeline(output, msgLine);
   end if;
   if error = '1' then
      write(msgLine, "ERROR: ");
      hwrite(msgLine, ecode);
      writeline(output, msgLine); 
   end if;
   --
end process;

-- 1 instantiation of Main Datapath
   DUT : aes_gcm_top
   generic map (
      w           => 128,
      block_size  => 128,
      key_size    => 128,
      tag_size    => 96,
      iv_size     => 96
   )
   port map (
      clk_i       => clock_tb,
      rst_i       => rst_i,
      pdi_ready   => pdi_ready,
      pdi_data    => pdi_data,
      pdi_read    => pdi_read,
      sdi_ready   => sdi_ready,
      sdi_data    => sdi_data,
      sdi_read    => sdi_read,
      do          => do,
      do_ready    => do_ready,
      do_write    => do_write,
      error       => error,
      ecode       => ecode    
   );
   
   
end architecture behavior;