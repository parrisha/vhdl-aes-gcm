--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity aes_gcm_top is
   generic (
      w           : natural := 16;
      block_size  : natural := 128;
      key_size    : natural := 128;
      tag_size    : natural := 96;
      iv_size     : natural := 96
   );
   port(
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      --Public Data Interface
      pdi_ready   : in  std_logic;
      pdi_data    : in  std_logic_vector(w-1 downto 0);
      pdi_read    : out std_logic;
      --Secret Data Interface
      sdi_ready   : in  std_logic;
      sdi_data    : in  std_logic_vector(w-1 downto 0);
      sdi_read    : out std_logic;
      --Data Out Interface
      do          : out std_logic_vector(w-1 downto 0);
      do_ready    : in  std_logic;
      do_write    : out std_logic;
      error       : out std_logic;
      ecode       : out std_logic_vector(7 downto 0)
   );
end aes_gcm_top;

architecture behavioral of aes_gcm_top is

signal aes_gcm_data             : std_logic_vector(block_size-1 downto 0);
signal aes_gcm_data_valid       : std_logic;
signal aes_gcm_data_source      : std_logic_vector(4 downto 0);
signal aes_gcm_msg_out          : std_logic_vector(block_size-1 downto 0);
signal aes_gcm_msg_out_valid    : std_logic;
signal aes_gcm_tag_out          : std_logic_vector(tag_size-1 downto 0);
signal aes_gcm_tag_out_valid    : std_logic;
signal aes_gcm_cipher_done      : std_logic;
signal aes_gcm_ghash_done       : std_logic;
signal aes_gcm_tag_matches      : std_logic;
signal aes_gcm_process_message  : std_logic;
signal aes_gcm_process_tag      : std_logic;
signal aes_gcm_ghash_in_select  : std_logic_vector(1 downto 0);
signal aes_gcm_ghash_last_input : std_logic;
signal aes_gcm_gctr_load_icb    : std_logic;
signal aes_gcm_compute_h        : std_logic;
signal aes_gcm_compute_tag      : std_logic;

signal pdi_data_wide  : std_logic_vector(127 downto 0);
signal pdi_ready_wide : std_logic;
signal pdi_read_wide  : std_logic;

signal sdi_data_wide  : std_logic_vector(127 downto 0);
signal sdi_ready_wide : std_logic;
signal sdi_read_wide  : std_logic;

begin

--Instantiate AES-GCM to perform the authenticated cipher

   controller : aes_gcm_controller
   generic map (
      w  => 128
   )
   port map (
      clk_i       => clk_i,   
      rst_i       => rst_i,   
      pdi_ready_i => pdi_ready,
      pdi_data_i  => pdi_data,
      pdi_read_o  => pdi_read,
      sdi_ready_i => sdi_ready,
      sdi_data_i  => sdi_data,
      sdi_read_o  => sdi_read,
      do          => do,      
      do_ready    => do_ready,
      do_write    => do_write,
      error       => error,   
      ecode       => ecode,   

      dp_data_o              => aes_gcm_data,
      dp_data_valid_o        => aes_gcm_data_valid,
      dp_data_source_o       => aes_gcm_data_source,
      dp_process_message     => aes_gcm_process_message,
      dp_process_tag         => aes_gcm_process_tag,
      dp_ghash_in_select     => aes_gcm_ghash_in_select,
      dp_ghash_last_input    => aes_gcm_ghash_last_input,
      dp_gctr_load_icb       => aes_gcm_gctr_load_icb,
      dp_compute_h           => aes_gcm_compute_h,
      dp_compute_tag         => aes_gcm_compute_tag,

      dp_msg_i       => aes_gcm_msg_out,
      dp_msg_valid_i => aes_gcm_msg_out_valid,
      dp_tag_i       => aes_gcm_tag_out,
      dp_tag_valid_i => aes_gcm_tag_out_valid,
      cipher_done_i  => aes_gcm_cipher_done,
      ghash_done_i   => aes_gcm_ghash_done,
      tag_matches_i  => aes_gcm_tag_matches
   );

   datapath : aes_gcm_datapath
   generic map (
      block_size  => block_size,
      cipher_type => "AES"
   )
   port map (
      clk_i   => clk_i,
      rst_i   => rst_i,
      -- Data Interface
      data_i              => aes_gcm_data, 
      data_valid_i        => aes_gcm_data_valid,
      data_source_i       => aes_gcm_data_source,
      msg_o               => aes_gcm_msg_out,
      msg_valid_o         => aes_gcm_msg_out_valid,
      tag_o               => aes_gcm_tag_out,
      tag_valid_o         => aes_gcm_tag_out_valid,
      cipher_done_o       => aes_gcm_cipher_done,
      ghash_cycle_done_o  => aes_gcm_ghash_done,
      tag_matches_o       => aes_gcm_tag_matches,
      process_message     => aes_gcm_process_message,
      process_tag         => aes_gcm_process_tag,
      ghash_in_select     => aes_gcm_ghash_in_select,
      ghash_in_last_input => aes_gcm_ghash_last_input,
      gctr_load_icb       => aes_gcm_gctr_load_icb,
      compute_h_i         => aes_gcm_compute_h,
      compute_tag         => aes_gcm_compute_tag
   );

end behavioral;