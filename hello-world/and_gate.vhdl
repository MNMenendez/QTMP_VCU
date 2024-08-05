-- and_gate.vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity and_gate is
    Port (
        a : in STD_LOGIC;
        b : in STD_LOGIC;
        c : out STD_LOGIC
    );
end and_gate;

architecture Behavioral of and_gate is
begin
    c <= a AND b;
end Behavioral;
