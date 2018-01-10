--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.aes_gcm_pkg.all;

entity aes_gcm_datapath is
   generic(
      block_size  : natural := 128;
      key_size    : natural := 128;
      tag_size    : natural := 96;
      iv_size     : natural := 96;
      cipher_type : string  := "AES"
   );
   port(
      clk_i       : in  std_logic;
      rst_i       : in  std_logic;
      --'1' to treat MSG input as P, '0' to treat MSG input as C
      --encrypt_i   : in  std_logic;
      --Generic Data input
      data_i       : in  std_logic_vector(block_size-1 downto 0);
      data_valid_i : in  std_logic;
      --Selects source of data (1-hot) as follows:
      -- 00001 : Key data
      -- 00010 : IV data
      -- 00100 : AAD data
      -- 01000 : MSG data
      -- 10000 : Tag data
      data_source_i : in  std_logic_vector(4 downto 0);
      --MSG interface (C or P)
      msg_o       : out std_logic_vector(block_size-1 downto 0);
      msg_valid_o : out std_logic;
      --Tag interface
      tag_o       : out std_logic_vector(tag_size-1 downto 0);
      tag_valid_o : out std_logic;
      --Other Controller Signals
      cipher_done_o       : out std_logic;
      ghash_cycle_done_o  : out std_logic;
      tag_matches_o       : out std_logic;
      process_message     : in  std_logic;
      process_tag         : in  std_logic;
      ghash_in_select     : in  std_logic_vector(1 downto 0);
      ghash_in_last_input : in  std_logic;
      gctr_load_icb       : in  std_logic;
      compute_h_i         : in  std_logic;
      compute_tag         : in  std_logic
   );
end aes_gcm_datapath;

architecture dataflow of aes_gcm_datapath is

signal key_valid : std_logic;
signal iv_valid  : std_logic;
signal aad_valid : std_logic;
signal msg_valid : std_logic;
signal tag_valid : std_logic;
signal key_data  : std_logic_vector(key_size-1 downto 0);
signal iv_data   : std_logic_vector(iv_size-1 downto 0);
signal aad_data  : std_logic_vector(block_size-1 downto 0);
signal msg_data  : std_logic_vector(block_size-1 downto 0);
signal tag_data  : std_logic_vector(tag_size-1 downto 0);

signal aad_length_reg    : std_logic_vector(56 downto 0);
signal aad_length_plus1  : std_logic_vector(56 downto 0);
signal msg_length_reg    : std_logic_vector(56 downto 0);
signal msg_length_plus1  : std_logic_vector(56 downto 0);
signal ghash_length_word : std_logic_vector(block_size-1 downto 0);

signal gctr_icb       : std_logic_vector(block_size-1 downto 0);

signal gctr_in                : std_logic_vector(block_size-1 downto 0);
signal gctr_in_valid          : std_logic;
signal gctr_out               : std_logic_vector(block_size-1 downto 0);
signal gctr_out_valid         : std_logic;
signal gctr_to_cipher         : std_logic_vector(block_size-1 downto 0);
signal gctr_to_cipher_valid   : std_logic;
signal gctr_from_cipher       : std_logic_vector(block_size-1 downto 0);
signal gctr_from_cipher_valid : std_logic;

signal j0        : std_logic_vector(block_size-1 downto 0);
signal j0_valid  : std_logic;
signal j0_inc32  : std_logic_vector(block_size-1 downto 0);
signal j0_reg    : std_logic_vector(block_size-1 downto 0);

signal ghash_in            : std_logic_vector(block_size-1 downto 0);
signal ghash_in_valid      : std_logic;

signal ghash_h             : std_logic_vector(block_size-1 downto 0);
signal h_valid             : std_logic;
signal ghash_out           : std_logic_vector(block_size-1 downto 0);
signal ghash_out_valid     : std_logic;

signal aes_cipher_in        : std_logic_vector(block_size-1 downto 0);
signal aes_cipher_in_valid  : std_logic;
signal aes_cipher_out       : std_logic_vector(block_size-1 downto 0);
signal aes_cipher_out_valid : std_logic;

begin

--Decode enable signals based on data_valid_i and data_source_i
key_valid <= data_valid_i and data_source_i(0);
iv_valid  <= data_valid_i and data_source_i(1);
aad_valid <= data_valid_i and data_source_i(2);
msg_valid <= data_valid_i and data_source_i(3);
tag_valid <= data_valid_i and data_source_i(4);

--Assign proper amount of data to each data input
key_data  <= data_i(key_size-1 downto 0);
iv_data   <= data_i(iv_size-1 downto 0);
aad_data  <= data_i(block_size-1 downto 0);
msg_data  <= data_i(block_size-1 downto 0);
tag_data  <= data_i(tag_size-1 downto 0);

----Count the number of AAD valid to use in GHASH
--aad_length_plus1 <= std_logic_vector(unsigned(aad_length_reg) + to_unsigned(1, 64));
--
--aad_length_register : register_async
--generic map (
--   n => 64
--)
--port map (
--   d_i           => aad_length_plus1,
--   en_i          => aad_valid,
--   reset_async_i => rst_i,
--   clk_i         => clk_i,
--   q_o           => aad_length_reg
--);

aad_length_counter : counter
generic map (
   n => 57
)
port map (
   d_i           => (others => '0'),
   en_i          => aad_valid,
   ld_i          => compute_tag,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => aad_length_reg
);

----Count the number of MSG valid to use in GHASH
--msg_length_plus1 <= std_logic_vector(unsigned(msg_length_reg) + to_unsigned(1, 64));
--
--msg_length_register : register_async
--generic map (
--   n => 64
--)
--port map (
--   d_i           => msg_length_plus1,
--   en_i          => msg_valid,
--   reset_async_i => rst_i,
--   clk_i         => clk_i,
--   q_o           => msg_length_reg
--);

msg_length_counter : counter
generic map (
   n => 57
)
port map (
   d_i           => (others => '0'),
   en_i          => msg_valid,
   ld_i          => compute_tag,
   reset_async_i => rst_i,
   clk_i         => clk_i,
   q_o           => msg_length_reg
);

--Multiply the word counts by 128 to get bit count
ghash_length_word <= aad_length_reg & "0000000" & msg_length_reg & "0000000";

-- 1 instantiation of GCTR
   gctr_inst : gctr_datapath
   generic map (
      block_size  => block_size,
      icb_size    => block_size
   )
   port map (
      clk_i      => clk_i,
      rst_i      => rst_i,
      icb_i      => gctr_icb,
      load_icb_i => gctr_load_icb,
      -- Data Interface
      x_i            => gctr_in,
      x_valid_i      => gctr_in_valid,
      y_o            => gctr_out,
      y_valid_o      => gctr_out_valid,
      cipher_o       => gctr_to_cipher,
      cipher_valid_o => gctr_to_cipher_valid,
      cipher_i       => gctr_from_cipher,
      cipher_valid_i => gctr_from_cipher_valid
   );
      
   j0_register : register_async
   generic map (
      n => block_size
   )
   port map (
      d_i           => j0,
      en_i          => j0_valid,
      reset_async_i => rst_i,
      clk_i         => clk_i,
      q_o           => j0_reg
   );
   
   j0 <= iv_data & x"00000001";
   j0_valid <= iv_valid;
   
   --INC32 of J0
   j0_inc32 <= j0_reg(block_size-1 downto 32) & std_logic_vector(unsigned(j0_reg(31 downto 0)) + to_unsigned(1, 32));
   
   --Mux to select proper ICB for GCTR
   gctr_icb <= j0_inc32 when process_message = '1' else j0_reg;
   
   --Mux to select input for GCTR
   gctr_in       <= msg_data  when process_message = '1' else ghash_out;
   gctr_in_valid <= msg_valid when process_message = '1' else ghash_out_valid;
   
-- 1 instantiation of GHASH
   --Mux to select input to GHASH
   -- AAD, C (MSG or GCTR_out), or Length
   with ghash_in_select select
      ghash_in <= aad_data when "00",
                  msg_data when "01",
                  gctr_out when "10",
                  ghash_length_word when others;
                  
   with ghash_in_select select
      ghash_in_valid <= aad_valid when "00",
                        msg_valid when "01",
                        gctr_out_valid when "10",
                        compute_tag when others;
   

   --Store H in a register so it is available for all GHASH operations
   h_valid <= aes_cipher_out_valid and not (process_message or process_tag);
   
   h_register : register_async
   generic map (
      n => block_size
   )
   port map (
      d_i           => aes_cipher_out,
      en_i          => h_valid,
      reset_async_i => rst_i,
      clk_i         => clk_i,
      q_o           => ghash_h
   );
   
   ghash_inst : ghash_datapath
   generic map (
      block_size  => block_size
   )
   port map (
      clk_i   => clk_i,
      rst_i   => rst_i,
      -- Data Interface
      x_i          => ghash_in,
      x_valid_i    => ghash_in_valid,
      x_last_input => ghash_in_last_input,
      ghash_done_o => ghash_cycle_done_o,
      h_i          => ghash_h,
      y_o          => ghash_out,
      y_valid_o    => ghash_out_valid
   );
   
--Compare external tag with internal tag (only valid same cycle as tag_valid_o)
   tag_matches_o <= '1' when (gctr_out(block_size-1 downto block_size-tag_size) = tag_data) else '0';
   
--Compute Tag Out from GCTR data
   tag_o       <= gctr_out(block_size-1 downto block_size-tag_size);
   tag_valid_o <= gctr_out_valid and process_tag;
   
--Since only supporting Encryption for now, just assign all Ciphertext to msg_out
   msg_o       <= gctr_out;
   msg_valid_o <= process_message and gctr_out_valid;
   
--The input to AES can either be the cipher output of GCTR or all 0 when computing H
   aes_cipher_in       <= gctr_to_cipher       when compute_h_i = '0' else (others => '0');
   aes_cipher_in_valid <= gctr_to_cipher_valid or compute_h_i;
   
--The output of AES can either be cipher input to GCTR or H
   gctr_from_cipher       <= aes_cipher_out;
   gctr_from_cipher_valid <= aes_cipher_out_valid and (process_message or process_tag);
   
   
CIPHER_AES : if (cipher_type = "AES") generate
   --Generate AES cipher and key generation/storage
   aes_inst: aes_datapath
   generic map (
      block_size  => block_size,
      key_size    => key_size,
      num_rounds  => 10
   )
   port map (
      clk_i          => clk_i,
      rst_i          => rst_i,
      cipher_i       => aes_cipher_in,
      cipher_valid_i => aes_cipher_in_valid,
      cipher_o       => aes_cipher_out,
      cipher_valid_o => aes_cipher_out_valid,
      key_i          => key_data,
      key_valid_i    => key_valid
   );
   
   cipher_done_o <= aes_cipher_out_valid;
   
end generate;

CIPHER_SIM : if (cipher_type = "AES_SIM") generate
   --Generate fake AES results used in initial simulation
   AES_KeyGen_Fake : process
   begin
      cipher_done_o <= '0';
      wait until key_valid = '1';
      wait for 500 ns;
      --Pretending AES Key Generation is done now, start H computation
      wait for 55 ns;
      ghash_h <= key_data xor x"FFFFFFFF00000000FFFFFFFF00000000";
      cipher_done_o <= '1';
      wait;
   end process;
   
   AES_Fake : process(clk_i)
   begin
      if rising_edge(clk_i) then
         if (rst_i = '1') then
            gctr_from_cipher_valid <= '0';
            gctr_from_cipher       <= (others => '0');
         elsif (gctr_to_cipher_valid = '1') then
            gctr_from_cipher_valid <= '1';
            gctr_from_cipher       <= gctr_to_cipher xor x"FFFFFFFF00000000FFFFFFFF00000000";
         else
            gctr_from_cipher_valid <= '0';
         end if;
      end if;
   end process;
   
end generate;

end dataflow;