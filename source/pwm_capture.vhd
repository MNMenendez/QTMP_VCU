---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : pwm_capture.vhd
-- Module      : pwm_capture
-- Revision    : 1.2
-- Date/Time   : Aug 22, 2018
-- Author      : Alvaro Lopes
---------------------------------------------------------------
-- Description : PWM Capture
---------------------------------------------------------------
-- History :
-- Revision 1.2 - Aug 22, 2018
--    - AFernandes: Applied code modifications for CCN02.
-- Revision 1.1 - March 07, 2018
--    - ALopes: Rework according to review
-- Revision 1.0 - January 24, 2018
--    - ALopes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

ENTITY pwm_capture IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- PWM capture pulse
      pulse_i              : IN  STD_LOGIC;
      -- PWM data input
      pwm_data_i           : IN  STD_LOGIC;
      -- PWM characteristic outputs
      pwm_high_o           : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
      pwm_update_o         : OUT STD_LOGIC;
      pwm_fault_o          : OUT STD_LOGIC 

   );

END ENTITY pwm_capture;

ARCHITECTURE beh OF pwm_capture IS

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
   -- CONSTANTS
   --------------------------------------------------------

   CONSTANT C_CLOCK_SPEED       : NATURAL   := 16384000;  -- Input clock speed in HZ
   CONSTANT C_CLOCK_DIVIDER     : NATURAL   := 64;        -- Divider (comes from external tick)

   -- Minimum and maximum period counters, to ensure PWM is within 10HZ range

   CONSTANT C_MIN_COUNT: NATURAL := ( (C_CLOCK_SPEED/C_CLOCK_DIVIDER)/510 ) - 1 ;  -- 500Hz +10Hz
   CONSTANT C_MAX_COUNT: NATURAL := ( (C_CLOCK_SPEED/C_CLOCK_DIVIDER)/490 ) - 1 ;  -- 500Hz -10Hz

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------

   SIGNAL count_r         : NATURAL RANGE 0 TO C_MAX_COUNT;   -- counter to check if maximum pwm period is reached
   SIGNAL duty_r          : NATURAL RANGE 0 TO C_MAX_COUNT;
   SIGNAL count_timeout_r : NATURAL RANGE 0 TO C_MAX_COUNT;   -- pwm transition check - timeout if no transition

   SIGNAL pwm_startup_r   : STD_LOGIC;

   SIGNAL reset_cnt_s     : STD_LOGIC;
   SIGNAL cmp_lt_max_s    : STD_LOGIC;
   SIGNAL cmp_gte_min_s   : STD_LOGIC;
   SIGNAL cmp_timeout_s   : STD_LOGIC;
   SIGNAL pwm_timeout_r   : STD_LOGIC;

   SIGNAL pwm_rise_s      : STD_LOGIC;
   SIGNAL pwm_fall_s      : STD_LOGIC;
   SIGNAL pwm_fault_r     : STD_LOGIC;
   SIGNAL pwm_high_r      : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm_update_r    : STD_LOGIC;

BEGIN

   cmp_lt_max_s       <= '1' WHEN count_r < C_MAX_COUNT ELSE '0';
   cmp_gte_min_s      <= '1' WHEN count_r >= C_MIN_COUNT ELSE '0';
   cmp_timeout_s      <= '1' WHEN count_timeout_r < C_MIN_COUNT ELSE '0';

   -- Reset period counter upon seeing a rising edge
   reset_cnt_s <= pwm_rise_s;

   -- Up counter with saturation.
   p_cnt: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         count_r<=0;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (reset_cnt_s = '1') THEN
            count_r<=0;
         ELSE
            IF (pulse_i = '1') THEN
               IF (cmp_lt_max_s = '1') THEN
                  count_r <= count_r + 1;
               END IF;
            END IF;
         END IF;
      END IF;
   END PROCESS p_cnt;

   -- Find timeouts 
   p_timeout: PROCESS(arst_i,clk_i)
   BEGIN
      IF arst_i='1' THEN
         count_timeout_r <= 0; 
         pwm_timeout_r   <= '0'; 
      ELSIF RISING_EDGE(clk_i) THEN
            IF (pulse_i = '1') THEN
               pwm_timeout_r   <= '0'; 
               IF (cmp_lt_max_s = '0') AND (cmp_timeout_s = '1') THEN 
                  count_timeout_r <= count_timeout_r + 1; 
               ELSIF (cmp_lt_max_s = '1') THEN 
                  count_timeout_r <= 0; 
               END IF; 
               IF (cmp_timeout_s = '0') THEN 
                  count_timeout_r <= 0; 
                  pwm_timeout_r   <= '1'; 
               END IF; 
            END IF; 
      END IF; 
   END PROCESS p_timeout;

   -- Capture duty cycle upon input falling edge
   p_duty_cap: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         duty_r<=0;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pwm_fall_s = '1' AND pulse_i = '1') THEN
            duty_r <= count_r;
         END IF;
      END IF;
   END PROCESS p_duty_cap;

   p_output: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         pwm_high_r     <= (OTHERS=>'0');
         pwm_update_r   <= '0';
         -- During first capture we don't want to propagate bogus data.
         -- This flag serves that purpose
         pwm_startup_r  <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         pwm_update_r <= '0';
         IF (pulse_i = '1') THEN
            IF (pwm_rise_s = '1') THEN
               -- We got an rising edge, capture period and duty cycle
               pwm_high_r     <= STD_LOGIC_VECTOR(TO_UNSIGNED(duty_r,10));
               IF (pwm_fault_r = '1') THEN
                  -- Mask PWM update if we have a PWM fault
                  pwm_update_r <= '0';
               ELSE
                  -- Only set update if this is at least the second measurement
                  pwm_update_r <= pwm_startup_r;
               END IF;
               pwm_startup_r <= '1';
            END IF;
         END IF;
      END IF;
   END PROCESS p_output;

   -- REQ BEGIN: 34
   p_fault_gen: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         pwm_fault_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse_i = '1') THEN
            IF ( (cmp_lt_max_s='0' AND pwm_timeout_r = '0') OR ( pwm_rise_s='1' AND cmp_gte_min_s='0' AND pwm_startup_r='1' ) ) THEN
               pwm_fault_r <= '1';
            ELSE
               pwm_fault_r <= '0';            --REQ: 192. Permanent fault only if threshold is reached
            END IF;
         END IF;
      END IF;
   END PROCESS p_fault_gen;
   -- REQ END: 34

   edge_detector_i0: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY => '1'
   )
   PORT MAP (
      arst_i         => arst_i,
      clk_i          => clk_i,
      valid_i        => pulse_i,
      data_i         => pwm_data_i,
      edge_o         => pwm_rise_s
   );

   edge_detector_i1: edge_detector
   GENERIC MAP (
      G_EDGEPOLARITY => '0'
   )
   PORT MAP (
      arst_i         => arst_i,
      clk_i          => clk_i,
      valid_i        => pulse_i,
      data_i         => pwm_data_i,
      edge_o         => pwm_fall_s
   );

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------

   pwm_fault_o    <= pwm_fault_r;                        -- REQ: 80
   pwm_high_o     <= pwm_high_r;
   pwm_update_o   <= pwm_update_r AND NOT pwm_fault_r;   -- Mask PWM update if we have a PWM fault 

END beh;


