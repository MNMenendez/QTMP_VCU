---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : pwm_input.vhd
-- Module      : PWM Input
-- Revision    : 1.5
-- Date/Time   : April 02, 2019
-- Author      : Alvaro Lopes, Ana Fernandes
---------------------------------------------------------------
-- Description : PWM Input
---------------------------------------------------------------
-- History :
-- Revision 1.5 - April 02, 2019
--    - AFernandes: Applied CCN03 code changes. 
-- Revision 1.4 - Oct 04, 2018
--    - AFernandes: code review in agreement with tests. 
-- Revision 1.3 - Aug 22, 2018
--    - AFernandes: Applied code modifications for CCN02.
-- Revision 1.2 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 24, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pwm_input IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- PWM capture pulse
      pulse_i              : IN  STD_LOGIC;
      -- PWM inputs for both channels
      pwm0_i               : IN  STD_LOGIC;
      pwm1_i               : IN  STD_LOGIC;
      -- PWM duty cycle out
      pwm0_duty_o           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm0_duty_valid_o     : OUT STD_LOGIC;
      pwm1_duty_o           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm1_duty_valid_o     : OUT STD_LOGIC;
      -- PWM faults
      pwm0_fault_o         : OUT STD_LOGIC;
      pwm1_fault_o         : OUT STD_LOGIC
   );

END ENTITY pwm_input;


ARCHITECTURE beh OF pwm_input IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   COMPONENT pwm_capture IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- PWM capture pulse
      pulse_i              : IN  STD_LOGIC;
      -- PWM data in
      pwm_data_i           : IN  STD_LOGIC;
      -- PWM characteristics out
      pwm_high_o           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm_update_o         : OUT STD_LOGIC;
      -- PWM fault
      pwm_fault_o          : OUT STD_LOGIC
   );
   END COMPONENT pwm_capture;


   COMPONENT pwm_compare IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- PWM Compare input
      pwm0_i               : IN  STD_LOGIC;
      pwm1_i               : IN  STD_LOGIC;
      pwm0_update_i        : IN  STD_LOGIC;
      pwm1_update_i        : IN  STD_LOGIC;
      pwm0_high_i          : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm1_high_i          : IN  STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm0_det_fault_i     : IN  STD_LOGIC;
      pwm1_det_fault_i     : IN  STD_LOGIC;

      -- PWM characteristic outputs
      pwm0_valid_o         : OUT STD_LOGIC;
      pwm1_valid_o         : OUT STD_LOGIC;
      pwm0_duty_o          : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm1_duty_o          : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm_compare_fault_o  : OUT STD_LOGIC
   );
   END COMPONENT pwm_compare;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL pwm0_high_s            : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm1_high_s            : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm0_update_s          : STD_LOGIC;
   SIGNAL pwm1_update_s          : STD_LOGIC;
   SIGNAL pwm0_det_fault_s       : STD_LOGIC;
   SIGNAL pwm1_det_fault_s       : STD_LOGIC;

   SIGNAL pwm0_1_r               : STD_LOGIC;
   SIGNAL pwm0_2_r               : STD_LOGIC;
   SIGNAL pwm1_1_r               : STD_LOGIC;
   SIGNAL pwm1_2_r               : STD_LOGIC;

   SIGNAL pwm0_valid_s           : STD_LOGIC;
   SIGNAL pwm1_valid_s           : STD_LOGIC;
   SIGNAL pwm0_duty_s            : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm1_duty_s            : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm_compare_fault_s    : STD_LOGIC;


   SIGNAL pwm0_temp_fault_s      : STD_LOGIC;
   SIGNAL pwm1_temp_fault_s      : STD_LOGIC;


BEGIN

   -- Sync inputs into our domain clock
   p_sync_inputs: PROCESS(arst_i, clk_i)
   BEGIN
      IF (arst_i='1') THEN
         pwm0_1_r <= '1';
         pwm1_1_r <= '1';
         pwm0_2_r <= '1';
         pwm1_2_r <= '1';
      ELSIF RISING_EDGE(clk_i) THEN
         pwm0_1_r <= NOT pwm0_i;
         pwm1_1_r <= NOT pwm1_i;
         pwm0_2_r <= pwm0_1_r;
         pwm1_2_r <= pwm1_1_r;
      END IF;
   END PROCESS p_sync_inputs;


   --------------------------------------------------------
   -- PWM CAPTURE
   --------------------------------------------------------

   pwm_capture_u0: pwm_capture
   PORT MAP (
      arst_i             => arst_i,
      clk_i              => clk_i,
      pulse_i            => pulse_i,
      pwm_data_i         => pwm0_2_r,
      pwm_high_o         => pwm0_high_s,
      pwm_update_o       => pwm0_update_s,
      pwm_fault_o        => pwm0_det_fault_s
   );

   pwm_capture_u1: pwm_capture
   PORT MAP (
      arst_i             => arst_i,
      clk_i              => clk_i,
      pulse_i            => pulse_i,
      pwm_data_i         => pwm1_2_r,
      pwm_high_o         => pwm1_high_s,
      pwm_update_o       => pwm1_update_s,
      pwm_fault_o        => pwm1_det_fault_s
   );

   --------------------------------------------------------
   -- PWM COMPARE
   --------------------------------------------------------

   pwm_compare_u0: pwm_compare
   PORT MAP (
      arst_i               => arst_i,
      clk_i                => clk_i,
      pwm0_i               => pwm0_2_r,
      pwm1_i               => pwm1_2_r,
      pwm0_update_i        => pwm0_update_s,
      pwm1_update_i        => pwm1_update_s,
      pwm0_high_i          => pwm0_high_s,
      pwm1_high_i          => pwm1_high_s,
      pwm0_det_fault_i     => pwm0_det_fault_s, 
      pwm1_det_fault_i     => pwm1_det_fault_s,

      pwm0_valid_o         => pwm0_valid_s,
      pwm1_valid_o         => pwm1_valid_s,
      pwm0_duty_o          => pwm0_duty_s,
      pwm1_duty_o          => pwm1_duty_s,
      pwm_compare_fault_o  => pwm_compare_fault_s
   );


   pwm0_temp_fault_s <= pwm0_det_fault_s OR pwm_compare_fault_s;       -- REQ: 34_80_81
   pwm1_temp_fault_s <= pwm1_det_fault_s OR pwm_compare_fault_s;



   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   pwm0_fault_o       <= pwm0_temp_fault_s;
   pwm1_fault_o       <= pwm1_temp_fault_s; 
   pwm0_duty_o        <= pwm0_duty_s;
   pwm0_duty_valid_o  <= pwm0_valid_s;
   pwm1_duty_o        <= pwm1_duty_s;
   pwm1_duty_valid_o  <= pwm1_valid_s;

END beh;


