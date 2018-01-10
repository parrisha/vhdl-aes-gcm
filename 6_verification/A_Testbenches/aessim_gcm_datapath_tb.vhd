--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_textio.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.aes_gcm_pkg.all;
  
entity aes_gcm_datapath_tb is
end aes_gcm_datapath_tb;

architecture  behavior of aes_gcm_datapath_tb is 

constant clock_period_tb : time := 20 ns; --50 MHz clock

file aesgcmTestVectorFile : text is in "aesgcm_datapath_test_vector1.txt";

signal clock_tb : std_logic;
signal rst_i : std_logic;

signal aes_gcm_encrypt        : std_logic;
signal aes_gcm_data           : std_logic_vector(127 downto 0);
signal aes_gcm_data_valid     : std_logic;
signal aes_gcm_data_source    : std_logic_vector(4 downto 0);
signal aes_gcm_msg_out        : std_logic_vector(127 downto 0);
signal aes_gcm_msg_out_valid  : std_logic;
signal aes_gcm_tag_out        : std_logic_vector(95 downto 0);
signal aes_gcm_tag_out_valid  : std_logic;
signal aes_gcm_key_done       : std_logic;
signal aes_gcm_message_active : std_logic;
signal aes_gcm_ghash_in_select : std_logic_vector(1 downto 0);
signal aes_gcm_ghash_last_input : std_logic;
signal aes_gcm_gctr_load_icb  : std_logic;

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
   variable space : character;
   variable fileValue : std_logic_vector(127 downto 0);
   variable fileValue96 : std_logic_vector(95 downto 0);
   variable fileValue2 : std_logic_vector(127 downto 0);
   variable fileInteger : integer;
   variable numAADWords : integer;
   variable numMSGWords : integer;
   variable wordsRead   : integer;
begin

   aes_gcm_message_active    <= '0';
   aes_gcm_ghash_in_select   <= "00";
   aes_gcm_ghash_last_input  <= '0';
   aes_gcm_gctr_load_icb     <= '0';
   aes_gcm_encrypt           <= '0';
   --Reset dut before applying any input
   rst_i   <= '1';
   wait for clock_period_tb * 5;
   rst_i   <= '0';
   
   aes_gcm_encrypt           <= '1';
   
   --Read Key from file (Expected as "K value")
   wait until rising_edge(clock_tb);
   vectorValid := false;
   while not vectorValid loop
      readline(aesgcmTestVectorFile, vectorLine);
      read(vectorLine, space);
      next when (space /= 'K');

      read(vectorLine, space); 
      hread(vectorLine, fileValue, good => vectorValid);
   end loop;
   --Apply key to Datapath
   aes_gcm_data        <= fileValue;
   aes_gcm_data_valid  <= '1';
   aes_gcm_data_source <= "00001";
   
   wait until rising_edge(clock_tb);
   aes_gcm_data_valid  <= '0';
   --Wait for key_done? (What actions depend on key?)
   while aes_gcm_key_done /= '1' loop
      wait until rising_edge(clock_tb);
   end loop;
   
   --Read IV from file (Expected as "I value")
   wait until rising_edge(clock_tb);
   vectorValid := false;
   while not vectorValid loop
      readline(aesgcmTestVectorFile, vectorLine);
      read(vectorLine, space);
      assert space = 'I'
         report "Did not read I"
         severity error;
      
      if (space = 'I') then
         read(vectorLine, space); 
         hread(vectorLine, fileValue96, good => vectorValid);
      end if;
   end loop;
   
   --Apply IV to Datapath, which computes J0
   aes_gcm_data        <= x"00000000" & fileValue96;
   aes_gcm_data_valid  <= '1';
   aes_gcm_data_source <= "00010";
   
   --After one clock, J0 is ready, apply it as the ICB for GCTR message processing
   wait until rising_edge(clock_tb);
   aes_gcm_data_valid     <= '0';
   aes_gcm_message_active <= '1';
   aes_gcm_gctr_load_icb  <= '1';
   wait until rising_edge(clock_tb);
   aes_gcm_gctr_load_icb <= '0';
   
   --Setup GHash for AAD
   aes_gcm_ghash_in_select <= "00";
   
   --Read numer of Additional Data words
   vectorValid := false;
   while not vectorValid loop
      readline(aesgcmTestVectorFile, vectorLine);
      read(vectorLine, space);
      next when (space /= 'A');

      read(vectorLine, space); 
      read(vectorLine, fileInteger, good => vectorValid);
   end loop;
   
   numAADWords := fileInteger;
   --Read Additional Data from File (128-bit values, one per line)
   --As each word is read, apply to Datapath
   wordsRead := 0;
   while wordsRead < numAADWords loop
      readline(aesgcmTestVectorFile, vectorLine);
      hread(vectorLine, fileValue, good => vectorValid);
      next when not vectorValid;
      
      wait until rising_edge(clock_tb);
      aes_gcm_data        <= fileValue;
      aes_gcm_data_valid  <= '1';
      aes_gcm_data_source <= "00100";
      wordsRead := wordsRead + 1;
   end loop;
   
   wait until rising_edge(clock_tb);
   aes_gcm_data_valid  <= '0';
   
   --Setup datapath to accept Plaintext input
   aes_gcm_message_active <= '1';
   aes_gcm_ghash_in_select <= "10";
   
   --Read number of plaintext words in file
   vectorValid := false;
   while not vectorValid loop
      readline(aesgcmTestVectorFile, vectorLine);
      read(vectorLine, space);
      next when (space /= 'P');

      read(vectorLine, space); 
      read(vectorLine, fileInteger, good => vectorValid);
   end loop;
   
   numMSGWords := fileInteger;
   --Read any plaintext from File (128-bit values, one per line)
   --Each plaintext word is followed directly by it's encrypted version
   --As each word is read, apply to Datapath
   wordsRead := 0;
   while wordsRead < numMSGWords loop
      readline(aesgcmTestVectorFile, vectorLine);
      hread(vectorLine, fileValue, good => vectorValid);
      next when not vectorValid;
      readline(aesgcmTestVectorFile, vectorLine);
      hread(vectorLine, fileValue2, good => vectorValid);
      
      write(testLine, "File: ");
      hwrite(testLine, fileValue2);
      writeline(output, testLine);
      
      wait until rising_edge(clock_tb);
      aes_gcm_data        <= fileValue;
      aes_gcm_data_valid  <= '1';
      aes_gcm_data_source <= "01000";
      wordsRead := wordsRead + 1;
      --Wait one cycle to allow for cipher.  Need to fix.
      wait until rising_edge(clock_tb);
      aes_gcm_data_valid  <= '0';
   end loop;
   
   wait until rising_edge(clock_tb);
   aes_gcm_data_valid  <= '0';
   
   --Trigger input of last GHASH word
   wait until rising_edge(clock_tb);
   aes_gcm_message_active <= '0';
   aes_gcm_ghash_in_select <= "11";
   aes_gcm_ghash_last_input <= '1';
   wait until rising_edge(clock_tb);
   aes_gcm_ghash_last_input <= '0';
   
   wait;
end process;

DutOutput : process
   variable msgLine : line;
   variable msgOut  : std_logic_vector(127 downto 0);
begin 
   --Wait for some data to be output from the datapath, could be C or Tag
   wait until rising_edge(clock_tb);
   wait until aes_gcm_msg_out_valid = '1';
   
   msgOut := aes_gcm_msg_out;
   write(msgLine, "CCA: ");
   hwrite(msgLine, aes_gcm_msg_out);
   writeline(output, msgLine);
   --
end process;

-- 1 instantiation of Main Datapath
   DUT : aes_gcm_datapath
   generic map (
      block_size  => 128,
      cipher_type => "AES_SIM"
   )
   port map (
      clk_i   => clock_tb,
      rst_i   => rst_i,
      -- Data Interface
      encrypt_i     => aes_gcm_encrypt,
      data_i        => aes_gcm_data, 
      data_valid_i  => aes_gcm_data_valid,
      data_source_i => aes_gcm_data_source,
      msg_o         => aes_gcm_msg_out,
      msg_valid_o   => aes_gcm_msg_out_valid,
      tag_o         => aes_gcm_tag_out,
      tag_valid_o   => aes_gcm_tag_out_valid,
      key_done_o    => aes_gcm_key_done,
      gctr_message  => aes_gcm_message_active,
      ghash_in_select => aes_gcm_ghash_in_select,
      ghash_in_last_input => aes_gcm_ghash_last_input,
      gctr_load_icb => aes_gcm_gctr_load_icb
   );
   
   
   
end architecture behavior;