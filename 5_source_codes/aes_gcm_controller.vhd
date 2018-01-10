--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity aes_gcm_controller is
   generic(
      w           : natural := 128;
      block_size  : natural := 128;
      key_size    : natural := 128;
      tag_size    : natural := 96;
      iv_size     : natural := 96
   );
   port(
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      --Public Data Interface
      pdi_ready_i   : in  std_logic;
      pdi_data_i    : in  std_logic_vector(w-1 downto 0);
      pdi_read_o    : out std_logic;
      --Secret Data Interface
      sdi_ready_i : in  std_logic;
      sdi_data_i  : in  std_logic_vector(w-1 downto 0);
      sdi_read_o  : out std_logic;
      --Data Out Interface
      do          : out std_logic_vector(w-1 downto 0);
      do_ready    : in  std_logic;
      do_write    : out std_logic;
      error       : out std_logic;
      ecode       : out std_logic_vector(7 downto 0);
      
      --Interface to Datapath
      dp_data_o              : out std_logic_vector(block_size-1 downto 0);
      dp_data_valid_o        : out std_logic;
      dp_data_source_o       : out std_logic_vector(4 downto 0);
      dp_process_message     : out std_logic;
      dp_process_tag         : out std_logic;
      dp_ghash_in_select     : out std_logic_vector(1 downto 0);
      dp_ghash_last_input    : out std_logic;
      dp_gctr_load_icb       : out std_logic;
      dp_compute_h           : out std_logic;
      dp_compute_tag         : out std_logic;
      --Interface from Datapath
      dp_msg_i       : in  std_logic_vector(block_size-1 downto 0);
      dp_msg_valid_i : in  std_logic;
      dp_tag_i       : in  std_logic_vector(tag_size-1 downto 0);
      dp_tag_valid_i : in  std_logic;
      cipher_done_i  : in  std_logic;
      ghash_done_i   : in  std_logic;
      tag_matches_i  : in  std_logic
   );
end aes_gcm_controller;

architecture behavioral of aes_gcm_controller is

type aes_gcm_states is (INIT, 
                       READ_INSTRUCTION,
                       READ_KEY_HEADER,
                       APPLY_KEY,
                       COMPUTE_H,
                       WAIT_H,
                       READ_IV_HEADER,
                       APPLY_IV,
                       COMPUTE_J0,
                       READ_AAD_HEADER,
                       APPLY_AAD,
                       WAIT_AAD,
                       READ_P_HEADER,
                       APPLY_P,
                       WAIT_P,
                       READ_TAG_HEADER,
                       COMPUTE_TAG,
                       COMPARE_TAG);


signal aes_gcm_controller_state : aes_gcm_states;

signal message_id : std_logic_vector(7 downto 0);
signal key_done   : std_logic;


signal pdi_read : std_logic;
signal sdi_read : std_logic;
signal pdi_data_d : std_logic_vector(w-1 downto 0);
signal sdi_data_d : std_logic_vector(w-1 downto 0);
signal data_out_select : std_logic_vector(1 downto 0);

signal aad_num_words     : std_logic_vector(w-21 downto 0);
signal msg_num_words     : std_logic_vector(w-21 downto 0);
signal num_words_applied : std_logic_vector(w-21 downto 0);
signal encrypt           : std_logic;

signal test              : std_logic_vector(3 downto 0);

begin

process(clk_i, rst_i)
begin
   if(rst_i = '1') then
      aes_gcm_controller_state <= INIT;
      error <= '0';
      ecode <= x"00";
      key_done <= '0';
      pdi_read <= '0';
      sdi_read <= '0';
      data_out_select     <= "00";
      dp_compute_h        <= '0';
      dp_compute_tag      <= '0';
      dp_gctr_load_icb    <= '0';
      dp_ghash_last_input <= '0';
      dp_ghash_in_select  <= "00";
      dp_process_message  <= '0';
      dp_process_tag      <= '0';
      dp_data_o           <= (others => '0');
      dp_data_valid_o     <= '0';
      dp_data_source_o    <= (others => '0');
   else
      if rising_edge(clk_i) then
         case aes_gcm_controller_state is
            when INIT =>
               --Reset state
               error <= '0';
               ecode <= x"00";
               key_done <= '0';
               pdi_read <= '0';
               sdi_read <= '0';
               data_out_select     <= "00";
               dp_compute_h        <= '0';
               dp_compute_tag      <= '0';
               dp_gctr_load_icb    <= '0';
               dp_ghash_last_input <= '0';
               dp_ghash_in_select  <= "00";
               dp_process_message  <= '0';
               dp_process_tag      <= '0';
               dp_data_o           <= (others => '0');
               dp_data_valid_o     <= '0';
               dp_data_source_o    <= (others => '0');
               aes_gcm_controller_state <= READ_INSTRUCTION;
               
            --   
            when READ_INSTRUCTION =>
               --Wait for data on either Secret or Public interface
               if (sdi_ready_i = '1') then
                  --There is a secret packet waiting
                  sdi_read <= '1';
                  --Assuming FWFT external fifo, so parse instruction
                  message_id <= sdi_data_i(w-1 downto w-8);
                  if (sdi_data_i(w-13 downto w-16) /= x"4") then
                     --Instruction recieved on secret that is not "LOAD KEY"
                     error <= '1';
                     ecode <= x"01";
                     aes_gcm_controller_state <= INIT;
                  else
                     aes_gcm_controller_state <= READ_KEY_HEADER;
                  end if;
               else
                  sdi_read <= '0';
               end if;
               
               --Only attempt to read public data if the key has been processed
               if (key_done = '1') then
                  data_out_select <= "01";
                  if (pdi_ready_i = '1') then
                     pdi_read <= '1';
                     if (pdi_data_i(w-13 downto w-16) /= x"2") then
                        --Instruction recieved that is not Authenticated Encryption
                        error <= '1';
                        ecode <= x"01";
                        aes_gcm_controller_state <= INIT;
                     else
                        aes_gcm_controller_state <= READ_IV_HEADER;
                     end if;
                  else
                     pdi_read <= '0';
                  end if;
               end if;
            
            --
            when READ_KEY_HEADER =>
               if (sdi_ready_i = '1') then
                  --There is a secret packet waiting
                  sdi_read <= '1';
                  --Assuming FWFT external fifo, so parse header
                  if (sdi_data_i(w-9 downto w-12) /= x"6") then
                     --Segment header does not match "Key"
                     test <= sdi_data_i(w-9 downto w-12);
                     error <= '1';
                     ecode <= x"07";
                     aes_gcm_controller_state <= INIT;
                  elsif (sdi_data_i(w-17 downto 0) /= std_logic_vector(to_unsigned(16, (w-16)))) then
                      --Only support 16 byte key length (128 bits)
                     error <= '1';
                     ecode <= x"03";
                     aes_gcm_controller_state <= INIT;
                  else
                     aes_gcm_controller_state <= APPLY_KEY;
                  end if;
               else
                  sdi_read <= '0';
               end if;  
               
            --
            when APPLY_KEY =>
               sdi_read <= '0';
               --Write the key to the datapath
               if (sdi_ready_i = '1') then
                  sdi_read <= '1';
                  --Assuming FWFT external fifo, so send data
                  dp_data_o        <= sdi_data_i;
                  dp_data_valid_o  <= '1';
                  dp_data_source_o <= "00001";
                  aes_gcm_controller_state <= COMPUTE_H;
               end if;
            
            --
            when COMPUTE_H =>
               sdi_read <= '0';
               
               dp_data_valid_o <= '0';
               dp_compute_h  <= '1';
               aes_gcm_controller_state <= WAIT_H;
               
            --
            when WAIT_H =>
               key_done <= '1';
               
               dp_compute_h <= '0';
               if (cipher_done_i = '1') then
                  aes_gcm_controller_state <= READ_INSTRUCTION;
               end if;
               
            --
            when READ_IV_HEADER =>
               if (pdi_ready_i = '1') then
                  --There is a public word waiting
                  pdi_read <= '1';
                  if (pdi_data_i(w-9 downto w-12) /= x"1") then
                     --Segment header does not match "IV"
                     error <= '1';
                     ecode <= x"06";
                     aes_gcm_controller_state <= INIT;
                  elsif (pdi_data_i(w-17 downto 0) /= std_logic_vector(to_unsigned(12, (w-16)))) then
                      --Only support 12 byte IV length (96 bits)
                     error <= '1';
                     ecode <= x"04";
                     aes_gcm_controller_state <= INIT;
                  else
                     aes_gcm_controller_state <= APPLY_IV;
                  end if;
               else
                  pdi_read <= '0';
               end if;
               
            --
            when APPLY_IV =>
               pdi_read <= '0';
               if (pdi_ready_i = '1') then
                  --There is a public word waiting
                  pdi_read <= '1';
                  --Assuming FWFT external fifo, so send data
                  dp_data_o        <= pdi_data_i;
                  dp_data_valid_o  <= '1';
                  dp_data_source_o <= "00010";
                  aes_gcm_controller_state <= COMPUTE_J0;
               end if;
            
            --
            when COMPUTE_J0 =>
               pdi_read <= '0';
               
               dp_data_valid_o <= '0';
               dp_process_message <= '1';
               dp_process_tag     <= '0';
               dp_gctr_load_icb   <= '1';
               aes_gcm_controller_state <= READ_AAD_HEADER;
               
            --
            when READ_AAD_HEADER =>
               dp_gctr_load_icb <= '0';
               if (pdi_ready_i = '1') then
                  --There is a public word waiting
                  pdi_read <= '1';
                  if (pdi_data_i(w-9 downto w-12) /= x"2") then
                     --Segment header does not match "AAD"
                     error <= '1';
                     ecode <= x"06";
                     aes_gcm_controller_state <= INIT;
                  else
                     aad_num_words <= pdi_data_i(w-17 downto 4);
                     num_words_applied <= (others => '0');
                     aes_gcm_controller_state <= APPLY_AAD;
                  end if;
               else
                  pdi_read <= '0';
               end if;
               
            --
            when APPLY_AAD =>
               if unsigned(num_words_applied) /= unsigned(aad_num_words) then
                  if (pdi_ready_i = '1') then
                     --There is a public word waiting
                     pdi_read <= '1';
                     num_words_applied <= std_logic_vector(unsigned(num_words_applied) + to_unsigned(1, num_words_applied'length));
                     --Assuming FWFT external fifo, so send data
                     dp_data_o        <= pdi_data_i;
                     dp_data_valid_o  <= '1';
                     dp_data_source_o <= "00100";
                  else
                     pdi_read <= '0';
                     dp_data_valid_o  <= '0';
                  end if;
               else
                  pdi_read <= '0';
                  dp_data_valid_o  <= '0';
                  aes_gcm_controller_state <= READ_P_HEADER;
               end if;
            
            --
            when WAIT_AAD =>
               pdi_read        <= '0';
               dp_data_valid_o <= '0';
               
               if (ghash_done_i = '1') then
                  aes_gcm_controller_state <= APPLY_AAD;
               end if;
               
            --
            when READ_P_HEADER =>
               if (pdi_ready_i = '1') then
                  --There is a public word waiting
                  pdi_read <= '1';
                  if (pdi_data_i(w-9 downto w-12) /= x"3") then
                     --Segment header does not match "Message"
                     error <= '1';
                     ecode <= x"06";
                     aes_gcm_controller_state <= INIT;
                  else
                     msg_num_words <= pdi_data_i(w-17 downto 4);
                     num_words_applied <= (others => '0');
                     
                     dp_ghash_in_select <= "10";
                     
                     aes_gcm_controller_state <= APPLY_P;
                  end if;
               else
                  pdi_read <= '0';
               end if;
               
            --
            when APPLY_P =>
               data_out_select <= "10";
               if unsigned(num_words_applied) /= unsigned(msg_num_words) then
                  if (pdi_ready_i = '1') then
                     --There is a public word waiting
                     pdi_read <= '1';
                     num_words_applied <= std_logic_vector(unsigned(num_words_applied) + to_unsigned(1, num_words_applied'length));
                     --Assuming FWFT external fifo, so send data
                     dp_data_o        <= pdi_data_i;
                     dp_data_valid_o  <= '1';
                     dp_data_source_o <= "01000";
                     aes_gcm_controller_state <= WAIT_P;
                  else
                     pdi_read <= '0';
                     dp_data_valid_o  <= '0';
                  end if;
               else
                  pdi_read <= '0';
                  dp_data_valid_o  <= '0';
                  --Although the cipher has completed, let the GHASH pipeline clear
                  if (ghash_done_i = '1') then
                     aes_gcm_controller_state <= READ_TAG_HEADER;
                  end if;
               end if;
            
            when WAIT_P =>
               pdi_read        <= '0';
               dp_data_valid_o <= '0';
               
               if (cipher_done_i = '1') then
                  aes_gcm_controller_state <= APPLY_P;
               end if;
            --
            when READ_TAG_HEADER =>
               data_out_select <= "01";
               if (pdi_ready_i = '1') then
                  --There is a public word waiting
                  pdi_read <= '1';
                  if (pdi_data_i(w-9 downto w-12) /= x"5") then
                     --Segment header does not match "Tag"
                     error <= '1';
                     ecode <= x"06";
                     aes_gcm_controller_state <= INIT;
                  elsif (pdi_data_i(w-17 downto 0) /= std_logic_vector(to_unsigned(12, (w-16)))) then
                      --Only support 12 byte Tag length (96 bits)
                     error <= '1';
                     ecode <= x"05";
                     aes_gcm_controller_state <= INIT;
                  else
                     aes_gcm_controller_state <= COMPUTE_TAG;
                  end if;
               else
                  pdi_read <= '0';
               end if;
               
            --
            when COMPUTE_TAG =>
               if (pdi_ready_i = '1') then
                  --There is a public word waiting
                  pdi_read <= '1';
                  dp_data_o        <= pdi_data_i;
                  dp_data_valid_o  <= '1';
                  dp_data_source_o <= "10000";
                  --Tell the datapath to compute the internal tag
                  dp_process_message <= '0';
                  dp_process_tag     <= '1';
                  dp_gctr_load_icb   <= '1';
                  dp_ghash_in_select <= "11";
                  dp_ghash_last_input <= '1';
                  dp_compute_tag      <= '1';
                  aes_gcm_controller_state <= COMPARE_TAG;
               else
                  pdi_read <= '0';
               end if;
                 
            --
            when COMPARE_TAG =>
               data_out_select <= "11";
               pdi_read <= '0';
               
               dp_data_valid_o  <= '0';
               dp_gctr_load_icb <= '0';
               dp_compute_tag   <= '0';
               
               if (dp_tag_valid_i = '1') then
                  if (tag_matches_i = '1') then
                     --YAY!
                     aes_gcm_controller_state <= INIT;
                  else
                     --Tag does not match!
                     error <= '1';
                     ecode <= x"08";
                     aes_gcm_controller_state <= INIT;
                  end if;
               end if;
               
         end case;
         
         pdi_data_d <= pdi_data_i;
         sdi_data_d <= sdi_data_i;
      end if;
   end if;
end process;

pdi_read_o <= pdi_read;
sdi_read_o <= sdi_read;


--This control of data output should maybe be in the datapath?  But since the controller needs to read
--  the input data stream as well it seems to fit here                       
with data_out_select select
   do <= sdi_data_d when "00",
         pdi_data_d when "01",
         dp_msg_i when "10",
         (x"00000000" & dp_tag_i) when others;

with data_out_select select
   do_write <= sdi_read when "00",
               pdi_read when "01",
               dp_msg_valid_i when "10",
               dp_tag_valid_i when others;
               
               
end behavioral;