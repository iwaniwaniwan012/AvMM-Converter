library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.all;
use work.AvMM_Pkg.all;

entity Example_User_Logic is
	generic (
		AVMM_ADDR_WIDTH 	: integer 	:= 8
	);
	port (
		AvMM_Clk				: in std_logic;
		AvMM_Reset 			: in std_logic;
		
		AvMM_Write  		: out std_logic;													--to Avalon Slave Module
		AvMM_Read        	: out std_logic;													--to Avalon Slave Module
		AvMM_Address     	: out std_logic_vector(AVMM_ADDR_WIDTH-1 downto 0);	--to Avalon Slave Module
		AvMM_Writedata   	: out std_logic_vector(31 downto 0);						--to Avalon Slave Module
		AvMM_Readdata    	: in std_logic_vector(31 downto 0);							--from Avalon Slave Module
		AvMM_Waitrequest 	: in std_logic;													--from Avalon Slave Module
		
		Rcfg_Req				: in std_logic;
		Rcfg_Done			: out std_logic
	);
end entity;

architecture behavioral of Example_User_Logic is

constant AVMM_ARRAY_LEN			: integer := 7;

signal const_wire_rcfg_avmm_data	: AvMM_Arr_t(AVMM_ARRAY_LEN-1 downto 0)(Addr(AVMM_ADDR_WIDTH-1 downto 0)) := (
	0 => (Cmd => '1', Addr => x"12", Wr_Data => x"00000000", Wr_Data_Mask => x"00000001", Rd_Data => (others => '0'), Rd_Data_Mask => (others => '0')),
	1 => (Cmd => '0', Addr => x"13", Wr_Data => (others => '0'), Wr_Data_Mask => (others => '0'), Rd_Data => x"00000001", Rd_Data_Mask => x"00000000"),
	2 => (Cmd => '0', Addr => x"14", Wr_Data => (others => '0'), Wr_Data_Mask => (others => '0'), Rd_Data => x"00000004", Rd_Data_Mask => x"00000000"),
	3 => (Cmd => '0', Addr => x"15", Wr_Data => (others => '0'), Wr_Data_Mask => (others => '0'), Rd_Data => (others => '0'), Rd_Data_Mask => x"00000000"),
	4 => (Cmd => '1', Addr => x"16", Wr_Data => (others => '0'), Wr_Data_Mask => x"00000001", Rd_Data => (others => '0'), Rd_Data_Mask => (others => '0')),
	5 => (Cmd => '1', Addr => x"17", Wr_Data => x"00000003", Wr_Data_Mask => x"00000003", Rd_Data => (others => '0'), Rd_Data_Mask => (others => '0')),
	6 => (Cmd => '0', Addr => x"18", Wr_Data => x"00000001", Wr_Data_Mask => x"00000001", Rd_Data => (others => '0'), Rd_Data_Mask => (others => '0'))
); 

signal const_wire_rcfg_avmm_data_mask : std_logic_vector(AVMM_ARRAY_LEN-1 downto 0) := (others => '1');

begin

m_AvMM_Conv: entity work.AvMM_Conv
	generic map (
		Avmm_Addr_Width 	=> AVMM_ADDR_WIDTH,
		AvMM_Data_Width	=> AVMM_ARRAY_LEN
	)
	port map (
		AvMM_Clk				=> AvMM_Clk,												--: in std_logic;
		AvMM_Reset 			=> AvMM_Reset,												--: in std_logic;
		
		AvMM_Write  		=> AvMM_Write,												--: out std_logic;
		AvMM_Read        	=> AvMM_Read,												--: out std_logic;
		AvMM_Address     	=> AvMM_Address,											--: out std_logic_vector(Addr_Width-1 downto 0);
		AvMM_Writedata   	=> AvMM_Writedata,										--: out std_logic_vector(31 downto 0);
		AvMM_Readdata    	=> AvMM_Readdata,											--: in std_logic_vector(31 downto 0);
		AvMM_Waitrequest 	=> AvMM_Waitrequest,										--: in std_logic;
		
		Rcfg_Req				=> Rcfg_Req,												--: in std_logic;
		AvMM_Data			=> const_wire_rcfg_avmm_data,							--: in AvMM_Arr_t(AvMM_Width-1 downto 0);
		AvMM_Data_Mask		=> const_wire_rcfg_avmm_data_mask,					--: in std_logic_vector(AvMM_Data_Width-1 downto 0);
		Rcfg_Done			=> Rcfg_Done												--: out std_logic
	);

end behavioral;