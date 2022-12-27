library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.all;
use work.AvMM_Pkg.all;

entity AvMM_Conv is
	generic (
		AVMM_ADDR_WIDTH 	: integer 	:= 10;
		AVMM_DATA_WIDTH	: integer 	:= 10
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
		AvMM_Data			: in AvMM_Arr_t(AVMM_DATA_WIDTH-1 downto 0);
		AvMM_Data_Mask		: in std_logic_vector(AVMM_DATA_WIDTH-1 downto 0);
		Rcfg_Done			: out std_logic
	);
end entity;

architecture behavioral of AvMM_Conv is

type state is (IDLE_ST, WORK_ST, WAIT_ST);

signal current_state : state := IDLE_ST;

signal wire_rmw_en					: std_logic 												:= '0';
signal wire_rmw_cmd					: std_logic 												:= '0';
signal wire_rmw_addr					: std_logic_vector(AVMM_ADDR_WIDTH-1 downto 0) 	:= (others => '0');
signal wire_rmw_wr_data				: std_logic_vector(31 downto 0) 						:= (others => '0');
signal wire_rmw_wr_data_mask		: std_logic_vector(31 downto 0) 						:= (others => '0');
signal wire_rmw_wr_done				: std_logic 												:= '0';
signal wire_rmw_rd_data				: std_logic_vector(31 downto 0) 						:= (others => '0');
signal wire_rmw_rd_data_valid		: std_logic 												:= '0';
signal wire_rmw_busy					: std_logic 												:= '0';

signal AvMM_Data_Cnt : integer range 0 to (AVMM_DATA_WIDTH-1) := 0;

begin

m_AvMM_RMW: entity work.AvalonMM_RMW
	generic map (
		Addr_Width 			=> AVMM_ADDR_WIDTH
	)
	port map (
		AvMM_Clk				=> AvMM_Clk,						--: in std_logic;
		AvMM_Reset 			=> AvMM_Reset,						--: in std_logic;
		
		AvMM_Write  		=> AvMM_Write,						--: out std_logic;
		AvMM_Read        	=> AvMM_Read,						--: out std_logic;
		AvMM_Address     	=> AvMM_Address,					--: out std_logic_vector(Addr_Width-1 downto 0);
		AvMM_Writedata   	=> AvMM_Writedata,				--: out std_logic_vector(31 downto 0);
		AvMM_Readdata    	=> AvMM_Readdata,					--: in std_logic_vector(31 downto 0);
		AvMM_Waitrequest 	=> AvMM_Waitrequest,				--: in std_logic;
		
		En_In					=> wire_rmw_en,					--: in std_logic;
		Cmd_In				=> wire_rmw_cmd,					--: in std_logic;
		Addr_In				=> wire_rmw_addr,					--: in std_logic_vector(Addr_Width-1 downto 0);
		Wr_Data_In			=> wire_rmw_wr_data,				--: in std_logic_vector(31 downto 0);
		Wr_Data_Mask_In	=> wire_rmw_wr_data_mask,		--: in std_logic_vector(31 downto 0);
		Wr_Done				=> wire_rmw_wr_done,				--: out std_logic;
		Rd_Data_Out			=> wire_rmw_rd_data,				--: out std_logic_vector(31 downto 0);
		Rd_Data_Valid_Out	=> wire_rmw_rd_data_valid,		--: out std_logic;
		Busy_Out				=> wire_rmw_busy					--: out std_logic
	);

process(AvMM_Clk) is
	begin
		if Rising_Edge(AvMM_Clk) then
			if AvMM_Reset = '1' then
				wire_rmw_en		<= '0';
				current_state	<= IDLE_ST;
			else
				case current_state is
					
					when IDLE_ST =>
					
						if Rcfg_Req = '1' then
							current_state <= WORK_ST;
						else
							current_state <= IDLE_ST;
						end if;
						
						Rcfg_Done <= '0';
						
					when WORK_ST =>
						
						if AvMM_Data_Mask(AvMM_Data_Cnt) = '0' then
							if AvMM_Data_Cnt = (AVMM_DATA_WIDTH-1) then
								AvMM_Data_Cnt 	<= 0;
								Rcfg_Done 		<= '1';
								current_state <= IDLE_ST;
							else
								AvMM_Data_Cnt 	<= AvMM_Data_Cnt + 1;
							end if;
							wire_rmw_en <= '0';
						else
							wire_rmw_en <= '1';
						end if;
						
						wire_rmw_cmd 				<= AvMM_Data(AvMM_Data_Cnt).Cmd;
						wire_rmw_addr 				<= AvMM_Data(AvMM_Data_Cnt).Addr;
						wire_rmw_wr_data			<= AvMM_Data(AvMM_Data_Cnt).Wr_Data;
						wire_rmw_wr_data_mask 	<= AvMM_Data(AvMM_Data_Cnt).Wr_Data_Mask;
						
						current_state <= WAIT_ST;
						
					when WAIT_ST =>
					
						wire_rmw_en <= '0';
						if AvMM_Data(AvMM_Data_Cnt).Cmd = '0' then
							if wire_rmw_rd_data_valid = '1' then
								current_state <= WORK_ST;
								if (wire_rmw_rd_data and AvMM_Data(AvMM_Data_Cnt).Rd_Data_Mask) = AvMM_Data(AvMM_Data_Cnt).Rd_Data then
									if AvMM_Data_Cnt = (AVMM_DATA_WIDTH-1) then
										AvMM_Data_Cnt 	<= 0;
										Rcfg_Done 		<= '1';
										current_state <= IDLE_ST;
									else
										AvMM_Data_Cnt <= AvMM_Data_Cnt + 1;
									end if;
								end if;
							end if;
						else
							if wire_rmw_wr_done = '1' then
								current_state <= WORK_ST;
								if AvMM_Data_Cnt = (AVMM_DATA_WIDTH-1) then
									AvMM_Data_Cnt 	<= 0;
									Rcfg_Done 		<= '1';
									current_state <= IDLE_ST;
								else
									AvMM_Data_Cnt 	<= AvMM_Data_Cnt + 1;
								end if;
							end if;
						end if;
						
					when others =>
						NULL;
				end case;
			end if;
		end if;
	end process;

end behavioral;