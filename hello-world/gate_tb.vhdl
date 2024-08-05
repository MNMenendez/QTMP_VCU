-- and_gate_tb.vhdl
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity and_gate_tb is
end and_gate_tb;

architecture behavior of and_gate_tb is
    signal a : STD_LOGIC := '0';
    signal b : STD_LOGIC := '0';
    signal c : STD_LOGIC;

    -- Component Declaration
    component and_gate
        Port (
            a : in STD_LOGIC;
            b : in STD_LOGIC;
            c : out STD_LOGIC
        );
    end component;

begin
    -- Instantiate the AND gate
    uut: and_gate
        Port Map (
            a => a,
            b => b,
            c => c
        );

    -- Test process
    process
    begin
        -- Test case 1
        a <= '0'; b <= '0';
        wait for 10 ns;
        assert (c = '0') report "Test case 1 failed" severity error;

        -- Test case 2
        a <= '0'; b <= '1';
        wait for 10 ns;
        assert (c = '0') report "Test case 2 failed" severity error;

        -- Test case 3
        a <= '1'; b <= '0';
        wait for 10 ns;
        assert (c = '0') report "Test case 3 failed" severity error;

        -- Test case 4
        a <= '1'; b <= '1';
        wait for 10 ns;
        assert (c = '1') report "Test case 4 failed" severity error;

        -- End simulation
        wait;
    end process;
end behavior;
