--ECE 545 Project
--Aaron Joe Parrish

library ieee;
use ieee.std_logic_1164.all;

package aes_gcm_pkg is	
   component aes_gcm_top
      generic (
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
   end component;

   component aes_gcm_datapath
      generic(
         block_size  : natural := 128;
         key_size    : natural := 128;
         tag_size    : natural := 96;
         iv_size     : natural := 96;
         cipher_type : string  := "AES"
      );
      port(
         clk_i               : in  std_logic;
         rst_i               : in  std_logic;
         data_i              : in  std_logic_vector(block_size-1 downto 0);
         data_valid_i        : in  std_logic;
         data_source_i       : in  std_logic_vector(4 downto 0);
         msg_o               : out std_logic_vector(block_size-1 downto 0);
         msg_valid_o         : out std_logic;
         tag_o               : out std_logic_vector(tag_size-1 downto 0);
         tag_valid_o         : out std_logic;
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
   end component;
   
   component aes_gcm_controller
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
         pdi_ready_i : in  std_logic;
         pdi_data_i  : in  std_logic_vector(w-1 downto 0);
         pdi_read_o  : out std_logic;
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
   end component;
   
   component ghash_datapath
      generic(
         block_size  : natural := 128
      );
      port(
         clk_i          : in  std_logic;
         rst_i          : in  std_logic;
         x_i            : in  std_logic_vector(block_size-1 downto 0);
         x_valid_i      : in  std_logic;
         x_last_input   : in  std_logic;
         ghash_done_o   : out std_logic;
         h_i            : in  std_logic_vector(block_size-1 downto 0);
         y_o            : out std_logic_vector(block_size-1 downto 0);
         y_valid_o      : out std_logic
      );
   end component;
   
   component ghash_datapath2 is
      generic(
         block_size  : natural := 128;
         mult_depth  : natural := 32
      );
      port(
         clk_i          : in  std_logic;
         rst_i          : in  std_logic;
         x_i            : in  std_logic_vector(block_size-1 downto 0);
         x_valid_i      : in  std_logic;
         x_last_input   : in  std_logic;
         ghash_done_o   : out std_logic;
         h_i            : in  std_logic_vector(block_size-1 downto 0);
         y_o            : out std_logic_vector(block_size-1 downto 0);
         y_valid_o      : out std_logic
      );
   end component;
   
   component gctr_datapath
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
   end component;
   
   component register_async
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
   end component;
   
   component register_async_1bit
      port(
         d_i           : in  std_logic;
         en_i          : in  std_logic;
         reset_async_i : in  std_logic;
         clk_i         : in  std_logic;
         q_o           : out std_logic
      );
   end component;

   component counter
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
   end component;
   
   component aes_datapath
      generic(
         block_size  : natural := 128;
         key_size    : natural := 128;
         num_rounds  : natural := 10
      );
      port (
         clk_i          : in  std_logic;
         rst_i          : in  std_logic;
         cipher_i       : in  std_logic_vector(block_size-1 downto 0);
         cipher_valid_i : in  std_logic;
         cipher_o       : out std_logic_vector(block_size-1 downto 0);
         cipher_valid_o : out std_logic;
         key_i          : in  std_logic_vector(key_size-1 downto 0);
         key_valid_i    : in  std_logic
      );
   end component;
   
   component aes_keygen
      generic (
         key_size    : natural := 128
      );
      port (
         clk_i         : in  std_logic;
         rst_i         : in  std_logic;
         key_i         : in  std_logic_vector(key_size-1 downto 0);
         key_valid_i   : in  std_logic;
         sync_i        : in  std_logic;
         round_key_o   : out std_logic_vector(key_size-1 downto 0)
      );
   end component;
 
--AES Components, copied from provided source code
   --component aes_round
   --   generic (
   --      rom_style : integer := 0
   --   );
   --   port ( 
   --      last_round	: in  std_logic;
   --      input 		: in  std_logic_vector(127 downto 0);
   --      key			: in  std_logic_vector(127 downto 0);
   --      output 		: out std_logic_vector(127 downto 0)
   --   );
   --end component; 
   
   component aes_mul
      generic (
      cons 	:integer := 3
      );
      port ( 
         input 		: in  std_logic_vector(7 downto 0);
         output 		: out std_logic_vector(7 downto 0)
      );
   end component;
   
   component aes_sbox is
      generic (
         rom_style :integer:=0
      );
      port ( 
         input 		: in  std_logic_vector(7 downto 0);
         output 		: out std_logic_vector(7 downto 0)
      );
   end component;
   
   
COMPONENT aes_gcm_interface_fifo
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    full : OUT STD_LOGIC;
    almost_full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    almost_empty : OUT STD_LOGIC
  );
END COMPONENT;

COMPONENT aes_gcm_interface_fifo_out
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    full : OUT STD_LOGIC;
    almost_full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    almost_empty : OUT STD_LOGIC
  );
END COMPONENT;

COMPONENT aes_gcm_error_fifo_out
  PORT (
    rst : IN STD_LOGIC;
    wr_clk : IN STD_LOGIC;
    rd_clk : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    almost_full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    almost_empty : OUT STD_LOGIC
  );
END COMPONENT;
end aes_gcm_pkg;