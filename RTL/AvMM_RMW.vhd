library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library altera_mf;
use altera_mf.all;

entity AvMM_RMW is
	generic (
		Addr_Width 			: integer := 10
	);
	port (
		AvMM_Clk				: in std_logic;
		AvMM_Reset 			: in std_logic;
		
		AvMM_Write  		: out std_logic;											--to Avalon Slave Module
		AvMM_Read        	: out std_logic;											--to Avalon Slave Module
		AvMM_Address     	: out std_logic_vector(Addr_Width-1 downto 0);	--to Avalon Slave Module
		AvMM_Writedata   	: out std_logic_vector(31 downto 0);				--to Avalon Slave Module
		AvMM_Readdata    	: in std_logic_vector(31 downto 0);					--from Avalon Slave Module
		AvMM_Waitrequest 	: in std_logic;											--from Avalon Slave Module
		
		En_In					: in std_logic;											--from User Logic
		Cmd_In				: in std_logic;											--from User Logic (0 - Read, 1 - Write)
		Addr_In				: in std_logic_vector(Addr_Width-1 downto 0);	--from User Logic
		Wr_Data_In			: in std_logic_vector(31 downto 0);					--from User Logic
		Wr_Data_Mask_In	: in std_logic_vector(31 downto 0);					--from User Logic
		Wr_Done				: out std_logic;											--to User Logic
		Rd_Data_Out			: out std_logic_vector(31 downto 0);				--to User Logic
		Rd_Data_Valid_Out	: out std_logic;											--to User Logic
		Busy_Out				: out std_logic											--to User Logic
	);
end entity;

architecture behavioral of AvMM_RMW is

component lpm_fifo
		generic (
			lpm_width 		: natural;
         lpm_widthu 		: natural := 1;
         lpm_numwords 	: natural;
			lpm_showahead 	: string := "OFF";
			lpm_type 		: string := "LPM_FIFO";
			lpm_hint 		: string := "UNUSED"
			);
		port (
			data 				: in std_logic_vector(lpm_width-1 downto 0);
			clock 			: in std_logic;
			wrreq				: in std_logic;
			rdreq 			: in std_logic;
			aclr 				: in std_logic := '0';
			sclr 				: in std_logic := '0';
			q 					: out std_logic_vector(lpm_width-1 downto 0);
			usedw 			: out std_logic_vector(lpm_widthU-1 downto 0);
			full 				: out std_logic;
			empty 			: out std_logic
			);
end component;

type state is (IDLE, READ_AVMM, WAIT_REQ, WRITE_AVMM);

type AvMM_RMW_R is record
	Cmd			: std_logic;
	Addr			: std_logic_vector(Addr_Width-1 downto 0);
	WrData		: std_logic_vector(31 downto 0);
	WrData_Mask	: std_logic_vector(31 downto 0);
	RdData		: std_logic_vector(31 downto 0);
end record;

signal AvMM_ReadData_Valid	: std_logic := '0';
signal dAvMM_WaitRequest	: std_logic := '0';

signal wire_fifo_data_in	: std_logic_vector(32+32+Addr_Width-1+1 downto 0) := (others => '0');
signal wire_fifo_data_out	: std_logic_vector(32+32+Addr_Width-1+1 downto 0) := (others => '0');
signal wire_fifo_rdreq		: std_logic := '0';
signal wire_fifo_wrreq		: std_logic := '0';
signal wire_fifo_usedw		: std_logic_vector(3 downto 0) := (others => '0');
signal wire_fifo_empty		: std_logic := '0';

signal RMW_Data : AvMM_RMW_R := (
			'0',
			(others => '0'),
			(others => '0'),
			(others => '0'),
			(others => '0')
			);
signal RMW_Last : std_logic := '0';
signal current_state : state := IDLE;

begin

FIFO_CMD: component lpm_fifo
		generic map (
			lpm_width 		=> 32+32+Addr_Width+1,
         lpm_widthu 		=> 4,
         lpm_numwords 	=> 16,
			lpm_showahead 	=> "OFF",
			lpm_type 		=> "LPM_FIFO"
			)
		port map(
			data 				=> wire_fifo_data_in,			--: in std_logic_vector(lpm_width-1 downto 0);
			clock 			=> AvMM_Clk,						--: in std_logic;
			wrreq				=> wire_fifo_wrreq,				--: in std_logic;
			rdreq 			=> wire_fifo_rdreq,				--: in std_logic;
			--aclr 				=> AvMM_Reset,						--: in std_logic := '0';
			sclr 				=> AvMM_Reset,						--: in std_logic := '0';
			q 					=> wire_fifo_data_out,			--: out std_logic_vector(lpm_width-1 downto 0);
			usedw 			=> wire_fifo_usedw,				--: out std_logic_vector(3 downto 0);
			full 				=> Busy_Out,						--: out std_logic;
			empty 			=> wire_fifo_empty				--: out std_logic
			);

dAvMM_WaitRequest <= AvMM_Waitrequest when Rising_Edge(AvMM_Clk);
AvMM_ReadData_Valid <= (not AvMM_Waitrequest) and dAvMM_WaitRequest;

wire_fifo_wrreq <= En_In;
wire_fifo_data_in <= Wr_Data_Mask_In & Wr_Data_In & Addr_In & Cmd_In;

wire_fifo_rdreq <= '1' when (current_state = IDLE and Rising_Edge(AvMM_Clk) and wire_fifo_usedw /= "0000") ;
--(not wire_fifo_empty)
RMW_Data.Cmd 			<= wire_fifo_data_out(0);
RMW_Data.Addr			<= wire_fifo_data_out(Addr_Width downto 1);
RMW_Data.WrData		<= wire_fifo_data_out(32+Addr_Width downto Addr_Width+1);
RMW_Data.WrData_Mask <= wire_fifo_data_out(32+32+Addr_Width downto Addr_Width+32+1);
RMW_Data.RdData		<= AvMM_Readdata;

AvMM_Address <= RMW_Data.Addr;

Rd_Valid: process(AvMM_Clk)
	begin
		if Rising_Edge(AvMM_Clk) then
			if AvMM_Reset = '1' then
				current_state <= IDLE;
			else
				case current_state is
				
					when IDLE =>
					
						AvMM_Read 			<= '0';
						AvMM_Write 			<= '0';
						Rd_Data_Valid_Out <= '0';
						Wr_Done				<= '0';
						RMW_Last 			<= '0';
						if wire_fifo_empty = '0' then
							current_state <= READ_AVMM;
						else
							current_state <= IDLE;
						end if;
						
					when READ_AVMM =>
						
						AvMM_Read 	<= '1';
						AvMM_Write 	<= '0';
						RMW_Last 	<= '0';
						current_state <= WAIT_REQ;
						
					when WAIT_REQ =>
					
						if AvMM_ReadData_Valid = '1' then
							AvMM_Read 	<= '0';
							AvMM_Write 	<= '0';
							if RMW_Data.Cmd = '1' then
								current_state 	<= WRITE_AVMM;
								--RMW_Data.RdData <= AvMM_Readdata;
								Rd_Data_Valid_Out <= '0';
							else
								Rd_Data_Out 		<= AvMM_Readdata;
								Rd_Data_Valid_Out <= '1';
								current_state 		<= IDLE;
							end if;
						else
							current_state <= WAIT_REQ;
						end if;
						
					when WRITE_AVMM =>
					
						AvMM_Read 		<= '0';
						AvMM_Write 		<= '1';
						AvMM_Writedata	<= ((not RMW_Data.WrData_Mask) and RMW_Data.RdData) or RMW_Data.WrData;
						current_state 	<= IDLE;
						Wr_Done 			<= '1';
						
					when others => NULL;
				end case;
			end if;
		end if;
	end process;

end behavioral;