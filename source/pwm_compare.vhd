---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : pwm_compare.vhd
-- Module      : pwm_compare
-- Revision    : 1.1
-- Date/Time   : February 04, 2020
-- Author      : Ana Fernandes, NRibeiro
---------------------------------------------------------------
-- Description : PWM Capture
---------------------------------------------------------------
-- History :
-- Revision 1.1 - February 04, 2020
--    - NRibeiro: Code coverage improvements.
-- Revision 1.0 - April 02, 2019
--    - AFernandes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pwm_compare IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- PWM compare inputs
      pwm0_i               : IN  STD_LOGIC;
      pwm1_i               : IN  STD_LOGIC;
      pwm0_update_i        : IN  STD_LOGIC;
      pwm1_update_i        : IN  STD_LOGIC;
      pwm0_high_i          : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm1_high_i          : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm0_det_fault_i     : IN  STD_LOGIC;
      pwm1_det_fault_i     : IN  STD_LOGIC;
      -- PWM compare outputs
      pwm0_valid_o         : OUT STD_LOGIC;
      pwm1_valid_o         : OUT STD_LOGIC;
      pwm0_duty_o          : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm1_duty_o          : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm_compare_fault_o  : OUT STD_LOGIC
   );

END ENTITY pwm_compare;

ARCHITECTURE beh OF pwm_compare IS

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------

   -- Use 8th bit for inter-PWM delay comparison
   -- This gives 15.625us
   CONSTANT C_BIT_DLY              : NATURAL := 8;

   --------------------------------------------------------
   -- TYPES
   --------------------------------------------------------

   TYPE state_TYP IS ( IDLE, WAIT_PWM0, WAIT_PWM1, WAIT_FALL0, WAIT_FALL1);

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL timeout_cnt_r          : UNSIGNED(8 DOWNTO 0);
   SIGNAL timeout_cnt_clr_s      : STD_LOGIC;

   SIGNAL pwm0_valid_r           : STD_LOGIC;
   SIGNAL pwm1_valid_r           : STD_LOGIC;
   SIGNAL pwm0_duty_r            : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm1_duty_r            : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm_compare_fault_r    : STD_LOGIC;

   SIGNAL det_state_r            : state_TYP;

   -- Compare two duty cycles. Return '1' if they are too far apart (delta > 5)
   FUNCTION duty_cycle_compare(d1: IN STD_LOGIC_VECTOR(9 DOWNTO 0); d2: IN STD_LOGIC_VECTOR(9 DOWNTO 0)) RETURN STD_LOGIC IS
      VARIABLE r_v: STD_LOGIC;
      VARIABLE s1_v, s2_v, s_v: SIGNED(10 DOWNTO 0);
      CONSTANT COMPARE_THRESHOLD: SIGNED(10 DOWNTO 0) := "00000000101"; -- 5 samples
   BEGIN
      s1_v := SIGNED("0" & d1);
      s2_v := SIGNED("0" & d2);

      s_v := s1_v - s2_v;
      s_v := ABS(s_v);
      IF ( s_v > COMPARE_THRESHOLD) THEN
         r_v := '1';
      ELSE
         r_v := '0';
      END IF;
      RETURN r_v;
   END FUNCTION;

BEGIN
   -- REQ BEGIN: 35
   p_counter: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         timeout_cnt_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (timeout_cnt_clr_s = '1') THEN
            timeout_cnt_r <= (OTHERS => '0');
         ELSIF (timeout_cnt_r(C_BIT_DLY) = '0') THEN
            timeout_cnt_r <= timeout_cnt_r + 1;
         END IF;
      END IF;
   END PROCESS p_counter;
   -- REQ END: 35

   timeout_cnt_clr_s<='1' WHEN det_state_r=IDLE ELSE '0';


   p_compare: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         det_state_r          <= IDLE;
         pwm_compare_fault_r  <= '0';
         pwm0_valid_r         <= '0';
         pwm1_valid_r         <= '0';
         pwm0_duty_r          <= (OTHERS =>'0');
         pwm1_duty_r          <= (OTHERS =>'0');
      ELSIF RISING_EDGE(clk_i) THEN

         pwm0_duty_r          <= pwm0_high_i;
         pwm1_duty_r          <= pwm1_high_i;
         CASE det_state_r IS

            -- WHEN IDLE =>                                                           -- IDLE state is now included in WHEN OTHERS condition

            WHEN WAIT_PWM0 =>
               -- Wait for PWM1 to be captured, or timeout
               IF (pwm0_det_fault_i ='1') THEN
                     pwm1_valid_r <= '1'; 
                     det_state_r <= IDLE;
               END IF;
               IF (timeout_cnt_r(C_BIT_DLY) = '1') THEN
                     pwm_compare_fault_r <= '1';                                      -- REQ: 35
                     det_state_r <= WAIT_FALL1;
               END IF;
               IF (pwm0_update_i = '1') THEN
                  IF (duty_cycle_compare(pwm0_high_i,pwm1_high_i) = '1') THEN
                     pwm_compare_fault_r <= '1';                                      -- REQ: 81
                  ELSE
                     pwm0_valid_r <= '1'; 
                     pwm1_valid_r <= '1'; 
                  END IF;
                  det_state_r <= IDLE;
               END IF;

            WHEN WAIT_PWM1 =>
               -- Wait for PWM1 to be captured, or timeout
               IF (pwm1_det_fault_i = '1') THEN
                     pwm0_valid_r <= '1'; 
                     det_state_r <= IDLE;
               END IF;
               IF (timeout_cnt_r(C_BIT_DLY) = '1') THEN
                     pwm_compare_fault_r <= '1';                                      -- REQ: 35
                     det_state_r <= WAIT_FALL0;
               END IF;
               IF (pwm1_update_i = '1') THEN
                  IF (duty_cycle_compare(pwm0_high_i,pwm1_high_i) = '1') THEN
                     pwm_compare_fault_r <= '1';                                      -- REQ: 81
                  ELSE
                     pwm0_valid_r <= '1'; 
                     pwm1_valid_r <= '1'; 
                  END IF;
                  det_state_r <= IDLE;
               END IF;

            WHEN WAIT_FALL0 =>
               -- Wait for PWM0 falling, or fault
               IF (pwm0_i = '0' OR pwm0_det_fault_i = '1') THEN
                     det_state_r <= IDLE; 
               END IF; 

            WHEN WAIT_FALL1 =>
               -- Wait for PWM1 falling, or fault
               IF (pwm1_i = '0' OR pwm1_det_fault_i = '1') THEN
                     det_state_r <= IDLE; 
               END IF; 

            WHEN OTHERS =>                                                            -- Include IDLE STATE
               pwm_compare_fault_r  <= '0';
               pwm0_valid_r <= '0';
               pwm1_valid_r <= '0'; 

               IF (pwm0_update_i='1' AND pwm1_update_i='0') THEN                      -- * Have valid PWM0 data
                  -- Wait for PWM1
                  det_state_r <= WAIT_PWM1;
               ELSIF (pwm1_update_i='1' AND pwm0_update_i='0') THEN                   -- * Have valid PWM1 data
                  -- Wait for PWM0
                  det_state_r <= WAIT_PWM0;
               ELSIF (pwm0_update_i='1' AND pwm1_update_i='1') THEN                   -- * Have valid PWM data for both channels 
                     IF (duty_cycle_compare(pwm0_high_i,pwm1_high_i) = '1') THEN
                        pwm_compare_fault_r <= '1';                                   -- REQ: 81
                     ELSE
                        pwm0_valid_r <= '1'; 
                        pwm1_valid_r <= '1'; 
                     END IF; 
               END IF;

         END CASE;
      END IF; 
   END PROCESS p_compare;

      --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

      pwm0_valid_o         <= pwm0_valid_r;
      pwm1_valid_o         <= pwm1_valid_r; 
      pwm0_duty_o          <= pwm0_duty_r;
      pwm1_duty_o          <= pwm1_duty_r;
      pwm_compare_fault_o  <= pwm_compare_fault_r;

END beh;


