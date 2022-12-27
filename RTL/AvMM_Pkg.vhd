library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;

package AvMM_Pkg is

type AvMM_t is record
	Cmd				: std_logic; --0 read, 1 write
	Addr				: std_logic_vector;
	Wr_Data			: std_logic_vector(31 downto 0);
	Wr_Data_Mask	: std_logic_vector(31 downto 0);
	Rd_Data			: std_logic_vector(31 downto 0);
	Rd_Data_Mask	: std_logic_vector(31 downto 0);
end record;

type AvMM_Arr_t is array(natural range <>) of AvMM_t; 

end package;