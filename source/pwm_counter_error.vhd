---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : pwm_counter_error.vhd
-- Module      : PWM Input
-- Revision    : 1.1
-- Date/Time   : April 05, 2019
-- Author      : Ana Fernandes
---------------------------------------------------------------
-- Description : PWM error counter
---------------------------------------------------------------
-- History :
-- Revision 1.1 - April 05, 2019
--    - AFernandes: Applied CCN03 code changes
-- Revision 1.0 - Aug 13, 2018
--    - AFernandes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE WORK.HCMT_CPLD_TOP_P.ALL;

ENTITY pwm_counter_error IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- valid PWM input 
      valid_i              : IN  STD_LOGIC;
      -- error input 
      fault_i              : IN  STD_LOGIC; 
      -- mask output 
      mask_o               : OUT STD_LOGIC; 
      -- Permanent fault output
      fault_o              : OUT STD_LOGIC
   );
END ENTITY pwm_counter_error;


ARCHITECTURE beh OF pwm_counter_error IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT edge_detector IS
   GENERIC (
      G_EDGEPOLARITY:  STD_LOGIC := '1'
   );
   PORT (
      arst_i   : IN  STD_LOGIC;
      clk_i    : IN  STD_LOGIC;
      valid_i  : IN  STD_LOGIC;
      data_i   : IN  STD_LOGIC;
      edge_o   : OUT STD_LOGIC
   );
   END COMPONENT edge_detector;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL counter_r              : UNSIGNED(13 DOWNTO 0);         --REQ: 191_192.
   SIGNAL fault_r                : STD_LOGIC;
   SIGNAL mask_r                 : STD_LOGIC;

   SIGNAL counter_zero_s         : STD_LOGIC;
   SIGNAL counter_max_s          : STD_LOGIC;
   SIGNAL rise_fault_event_s     : STD_LOGIC;
   SIGNAL rise_valid_event_s     : STD_LOGIC;

BEGIN

   counter_zero_s <= '1' WHEN counter_r="00000000000000" ELSE '0';  -- REQ: 191. Minimum counter value
   counter_max_s <= '1' WHEN counter_r="11111111111111" ELSE '0';   -- REQ: 192. Maximum counter value

   edge_detector_i0: edge_detector                                  -- Check new pwm error 
   GENERIC MAP (
      G_EDGEPOLARITY => '1'
   ) PORT MAP (
      arst_i   => arst_i,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => fault_i,
      edge_o   => rise_fault_event_s
   );

   edge_detector_i1: edge_detector                                  -- Check new valid pwm input
   GENERIC MAP (
      G_EDGEPOLARITY => '1'
   ) PORT MAP (
      arst_i   => arst_i,
      clk_i    => clk_i,
      valid_i  => '1',
      data_i   => valid_i,
      edge_o   => rise_valid_event_s
   );

   -- REQ BEGIN: 191, 192
   p_fault: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         counter_r <= (OTHERS =>'0');
         fault_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN

         IF (counter_max_s = '1') THEN 
            fault_r <= '1';                                             -- REQ: 192
         END IF;

         IF (rise_fault_event_s = '1' AND fault_r = '0') THEN 
            counter_r <= counter_r + 1;

         ELSIF (rise_valid_event_s = '1' AND fault_r = '0') THEN
            -- If valid data, decrement accordingly
            IF (counter_zero_s = '0') THEN
               counter_r <= counter_r - 1;
            END IF;
         END IF;
      END IF;
   END PROCESS p_fault;

   p_mask: PROCESS(arst_i,clk_i)                                        -- REQ: 191
   BEGIN
      IF (arst_i = '1') THEN
         mask_r    <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
          IF (counter_zero_s = '1' AND fault_r = '0') THEN 
             mask_r <= '0';
          ELSE
             mask_r <= '1';
          END IF;
      END IF;
   END PROCESS p_mask;
-- REQ END: 191, 192

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   fault_o <= fault_r; 
   mask_o  <= mask_r; 

END beh;
