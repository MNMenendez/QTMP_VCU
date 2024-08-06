---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : demand_phase_det.vhd
-- Module      : Input IF
-- Revision    : 1.10
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, Afernandes, NRibeiro
---------------------------------------------------------------
-- Description : Analog Speed Encoder IF
---------------------------------------------------------------
-- History :
-- Revision 1.10- May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.9 - April 14, 2021
--    - NRibeiro: [CCN05] Applied/Updated with CCN05 changes related to Requirements
--                 REQ 121, REQ 38, REQ 39 and REQ 219
-- Revision 1.8 - February 04, 2020
--    - NRibeiro: Small Fixes related to REQs 191_215_216 and to improve code coverage
-- Revision 1.7 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.6 - November 29,2019
--    - NRibeiro: Range of valid values for PWM duty cycles was fine-tuned
-- Revision 1.5 - October 22, 2019
--    - NRibeiro: Changed how brk_dmnd_o and brk_dmnd_o are calculated
-- Revision 1.4 - June 12, 2019
--    - AFernandes: Applied CCN03 code changes
-- Revision 1.3 - April 05, 2019
--    - JMonteiro: Applied code review comments.
-- Revision 1.2 - March 02, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - February 09, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY demand_phase_det IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i      : IN STD_LOGIC;                        -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  PWM Inputs
      ----------------------------------------------------------------------------
      pwm0_duty_i        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);     -- PWM DC
      pwm0_duty_valid_i  : IN STD_LOGIC;                        -- Signals valid PWM DC reading
      pwm1_duty_i        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);     -- PWM DC
      pwm1_duty_valid_i  : IN STD_LOGIC;                        -- Signals valid PWM DC reading

      pwm0_fault_i       : IN STD_LOGIC;                        -- PWM0 fault
      pwm1_fault_i       : IN STD_LOGIC;                        -- PWM1 fault

      ----------------------------------------------------------------------------
      --   Fault Inhibit Input
      ----------------------------------------------------------------------------
      inhibit_fault_i    : IN STD_LOGIC;                        -- Inhibit generation of PWM faults

      ----------------------------------------------------------------------------
      --  OUTPUTS
      ----------------------------------------------------------------------------
      pwm0_fault_o      : OUT STD_LOGIC;                       -- PWM0 fault
      pwm1_fault_o      : OUT STD_LOGIC;                       -- PWM1 fault

      pwr_brk_dmnd_o    : OUT STD_LOGIC;                       -- Movement of MC changing ±5% the braking demand or 
                                                               --            ±5% the power demand (req 38 and req 39)  
      mc_no_pwr_o       : OUT STD_LOGIC                        -- MC = No Power

   );
END ENTITY demand_phase_det;


ARCHITECTURE beh OF demand_phase_det IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------
   -- Edge Detector
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

   -- Interpret DC Values
   COMPONENT pwm_dc_thr IS
      PORT
      (
         arst_i            : IN STD_LOGIC;                        -- Global (asynch) reset
         clk_i             : IN STD_LOGIC;                        -- Global clk
         pwm_duty_i        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);     -- PWM DC
         pwm_duty_valid_i  : IN STD_LOGIC;                        -- Signals valid PWM DC reading
         pwm_fault_i       : IN STD_LOGIC;                        -- PWM fault
         inhibit_fault_i   : IN STD_LOGIC;                        -- Inhibit generation of PWM faults
         pwm_duty_o        : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);    -- PWM DC
         pwm_duty_valid_o  : OUT STD_LOGIC;                       -- Signals valid PWM DC reading
         pwm_update_o      : OUT STD_LOGIC;                       -- Signals PWM DC Update
         pwm_fault_o       : OUT STD_LOGIC;                       -- PWM0 fault
         mc_no_pwr_o       : OUT STD_LOGIC                        -- MC = No Power
      );
      END COMPONENT pwm_dc_thr;

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------
   CONSTANT C_CTR_3S          : UNSIGNED(12 DOWNTO 0) := TO_UNSIGNED(6000,13);  -- 3 sec counter
   
   -- [CCN05] New differece value was defined instead of 4.16%, now is 5.0%
   --              REQ 121,  REQ 38  and  REQ 39           
   -- Absolute difference of 5.0% in PWM DC round(511*(5.0)/100 = 25.55) = 26
   CONSTANT C_ABS05dot00_PCNT : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED( 26,10);   
      
   -- [CCN05] PWM DC Thresholds were redefined affecting REQ: 37 and  REQ: 37.01 to REQ: 37.08 
   --           and many threshold Constants definitions were removed
   --   The following defined Constants are related to REQ: 38 and REQ: 39

   -- Absolute DC 10%                       round(511*(10.0)/100 =  51.10) = 51
   CONSTANT C_ABS10_PCNT      : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED( 51,10);  
   
   -- Absolute DC 49% (50% - 1% tolerance)  round(511*(49.0)/100 = 250.39) = 250
   CONSTANT C_ABS49_PCNT      : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED(250,10);   

   -- Absolute DC 51% (50% + 1% tolerance)  round(511*(51.0)/100 = 260.61) = 261
   CONSTANT C_ABS51_PCNT      : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED(261,10);   
   
   -- Absolute DC 90%                       round(511*(90.0)/100 = 459.99) = 460
   CONSTANT C_ABS90_PCNT      : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED(460,10);   
   
   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   SIGNAL pwm_duty_s       : UNSIGNED(9 DOWNTO 0);

   SIGNAL pwm0_duty_s       : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm0_duty_valid_s : STD_LOGIC;
   SIGNAL pwm0_update_s     : STD_LOGIC;
   SIGNAL pwm0_fault_s      : STD_LOGIC;
   SIGNAL mc0_no_pwr_s      : STD_LOGIC;

   SIGNAL pwm1_duty_s       : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm1_duty_valid_s : STD_LOGIC;
   SIGNAL pwm1_update_s     : STD_LOGIC;
   SIGNAL pwm1_fault_s      : STD_LOGIC;
   SIGNAL mc1_no_pwr_s      : STD_LOGIC;

   SIGNAL pwm_duty_r       : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm_update_r     : STD_LOGIC;

   SIGNAL ctr_3s_s         : UNSIGNED(12 DOWNTO 0);
   SIGNAL ctr_3s_r         : UNSIGNED(12 DOWNTO 0);
   SIGNAL ctr_3s_rst_s     : STD_LOGIC;

   SIGNAL pwm_duty_min_s   : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwm_duty_min_r   : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwm_duty_max_s   : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwm_duty_max_r   : UNSIGNED(9 DOWNTO 0);

   SIGNAL brk_dmnd_s       : STD_LOGIC;
   SIGNAL brk_dmnd_r       : STD_LOGIC;
   SIGNAL pwr_dmnd_s       : STD_LOGIC;
   SIGNAL pwr_dmnd_r       : STD_LOGIC;

   SIGNAL brk_max_s        : UNSIGNED(9 DOWNTO 0);
   SIGNAL brk_min_s        : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwr_max_s        : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwr_min_s        : UNSIGNED(9 DOWNTO 0);

   SIGNAL brk_dmnd_r_s     : STD_LOGIC;
   SIGNAL brk_dmnd_re_s    : STD_LOGIC;

   SIGNAL pwr_dmnd_r_s     : STD_LOGIC;
   SIGNAL pwr_dmnd_re_s    : STD_LOGIC;

   SIGNAL mc_no_pwr_r      : STD_LOGIC;

   SIGNAL pwm_duty_ref_r   : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwm_update_r1    : STD_LOGIC;

BEGIN


   -- Interpret DC Values
   pwm_dc_thr_u0: pwm_dc_thr
   PORT MAP (
         arst_i           => arst_i,
         clk_i            => clk_i,
         pwm_duty_i       => pwm0_duty_i,
         pwm_duty_valid_i => pwm0_duty_valid_i,
         pwm_fault_i      => pwm0_fault_i,
         inhibit_fault_i  => inhibit_fault_i,   -- when cab is inactive, pwm error counters should be paused REQ: 205
         pwm_duty_o       => pwm0_duty_s,                
         pwm_duty_valid_o => pwm0_duty_valid_s,                
         pwm_update_o     => pwm0_update_s,                 
         pwm_fault_o      => pwm0_fault_s,                  
         mc_no_pwr_o      => mc0_no_pwr_s                
      );                
                  
   pwm_dc_thr_u1: pwm_dc_thr                 
   PORT MAP (                 
         arst_i           => arst_i,                  
         clk_i            => clk_i,                
         pwm_duty_i       => pwm1_duty_i,                
         pwm_duty_valid_i => pwm1_duty_valid_i,                
         pwm_fault_i      => pwm1_fault_i,                  
         inhibit_fault_i  => inhibit_fault_i,   -- when cab is inactive, pwm error counters should be paused REQ: 205
         pwm_duty_o       => pwm1_duty_s,
         pwm_duty_valid_o => pwm1_duty_valid_s,
         pwm_update_o     => pwm1_update_s,
         pwm_fault_o      => pwm1_fault_s,
         mc_no_pwr_o      => mc1_no_pwr_s
      );

   p_compare: PROCESS(arst_i,clk_i)
   BEGIN
      IF arst_i='1' THEN
         pwm_update_r          <= '0';
         pwm_duty_r            <= STD_LOGIC_VECTOR(TO_UNSIGNED(256, pwm_duty_r'length));
         mc_no_pwr_r           <= '0';
   ELSIF RISING_EDGE(clk_i) THEN                                
         
         -- REQ: 191_215 (Conditions which disregards updating the duty_cycle value)  
         IF ((pwm0_duty_valid_s = '1') AND (pwm0_update_s = '1')) THEN        -- * PWM0 data valid 
            pwm_update_r          <= '1';
            pwm_duty_r            <= pwm0_duty_s;
         ELSIF ((pwm1_duty_valid_s = '1') AND (pwm1_update_s = '1')) THEN     -- * PWM1 data valid
            pwm_update_r          <= '1';
            pwm_duty_r            <= pwm1_duty_s;
         ELSE
            pwm_update_r          <= '0';
         END IF;
                                                                              -- Code for "mc0_no_pwr_s" was not 
                                                                              --  changed from CCN03 due to REQ: 194
         IF (pwm0_duty_valid_s = '1') THEN                                    -- * PWM0 data valid 
            mc_no_pwr_r           <= mc0_no_pwr_s;
         ELSE                                                                 -- * PWM1 data valid or none Valid
            mc_no_pwr_r           <= mc1_no_pwr_s;
         END IF;                 
         
      END IF;
   END PROCESS p_compare;

   -- NR (2019/10/22):
   --    pwm_duty_s signal should only have values in the valid range [C_ABS10_PCNT ; C_ABS90_PCNT[,
   --    for the min/max calculation to work properly                         -- REQ START: 216
   pwm_duty_s <= (C_ABS90_PCNT) when UNSIGNED(pwm_duty_r) > C_ABS90_PCNT else
                 (C_ABS10_PCNT) when UNSIGNED(pwm_duty_r) < C_ABS10_PCNT else
                 UNSIGNED(pwm_duty_r);
                                                                              -- REQ END: 216

   --------------------------------------------------------
   -- PHASE / POWER DEMAND CALC
   --------------------------------------------------------
   p_bp_dmnd: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         brk_dmnd_r     <= '0';
         pwr_dmnd_r     <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
            brk_dmnd_r     <= brk_dmnd_s;
            pwr_dmnd_r     <= pwr_dmnd_s;
      END IF;
   END PROCESS p_bp_dmnd;


   -- [CCN05] REQ: 38  new range for brake demand                                       -- REQ 219
   brk_max_s <= C_ABS51_PCNT    WHEN (pwm_duty_max_r > C_ABS51_PCNT)               ELSE -- sets to 51%, if >51% 
                pwm_duty_max_r;

   brk_min_s <= pwm_duty_min_r;

   brk_dmnd_s <= '1'            WHEN ((brk_max_s - brk_min_s) >= C_ABS05dot00_PCNT AND  -- REQ 121
                                      (brk_min_s < brk_max_s))                     ELSE
                 '0';

   -- [CCN05] REQ: 39 new range for brake demand
   pwr_max_s <= pwm_duty_max_r;
                                                                                         -- REQ 219
   pwr_min_s <= C_ABS49_PCNT    WHEN (pwm_duty_min_r < C_ABS49_PCNT)               ELSE  -- sets to 49%, if <49%
                pwm_duty_min_r;

   pwr_dmnd_s <= '1'            WHEN ((pwr_max_s - pwr_min_s) >= C_ABS05dot00_PCNT AND   -- REQ 121
                                      (pwr_min_s < pwr_max_s))                     ELSE
                 '0';

   --------------------------------------------------------
   -- MIN / MAX PWM DC CALC
   --------------------------------------------------------                              -- REQ START: 38_39
   -- Get min and max readings of breaking/power demand phase in 3s window
   p_dc_rng: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         pwm_duty_min_r <= TO_UNSIGNED(256, pwm_duty_min_r'length);
         pwm_duty_max_r <= TO_UNSIGNED(256, pwm_duty_max_r'length);
         pwm_duty_ref_r <= TO_UNSIGNED(256, pwm_duty_ref_r'length);
         pwm_update_r1 <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
            pwm_update_r1 <= pwm_update_r;
            pwm_duty_min_r <= pwm_duty_min_s;
            pwm_duty_max_r <= pwm_duty_max_s;
            IF (pwm_update_r ='1') THEN
                pwm_duty_ref_r <= pwm_duty_s;
            END IF;
      END IF;
   END PROCESS p_dc_rng;


   -- NR (2019/10/22):
   -- Now, the comparation of the stored value (pwm_duty_min_s/pwm_duty_max_s) with the last pwm_duty measured 
   --  (pwm_duty_ref_r) only happens in the following clock cycle of pwm_duty_ref_r being updated 
   --  (pwm_update_r assertion)
   -- The values of (pwm_duty_min_s/pwm_duty_max_s) are deleted/forgotten and updated to the last value of 
   --   pwm_duty_ref_r whenever there is a TLA event, a measure that it is out of range 
   --   ( > C_ABS90_PCNT or < C_ABS10_PCNT) or a 3s window timeout.
   pwm_duty_min_s <= pwm_duty_ref_r WHEN ((pwm_duty_ref_r < pwm_duty_min_r) AND (pwm_update_r1='1')) OR 
                                          (ctr_3s_rst_s = '1') ELSE
                     pwm_duty_min_r;

   pwm_duty_max_s <= pwm_duty_ref_r WHEN ((pwm_duty_ref_r > pwm_duty_max_r) AND (pwm_update_r1='1')) OR 
                                          (ctr_3s_rst_s = '1') ELSE
                     pwm_duty_max_r;

   --------------------------------------------------------
   -- 3 SECOND COUNTER
   --------------------------------------------------------
   p_ctr_3s: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         ctr_3s_r <= (C_CTR_3S-1);
      ELSIF RISING_EDGE(clk_i) THEN
         IF ((pulse500us_i = '1') OR (ctr_3s_rst_s = '1')) THEN
            ctr_3s_r <= ctr_3s_s;
         END IF;
      END IF;
   END PROCESS p_ctr_3s;

   ctr_3s_rst_s <= '1' WHEN ((brk_dmnd_re_s = '1') OR (pwr_dmnd_re_s = '1') OR (ctr_3s_r = 0)) ELSE
                   '0';

   ctr_3s_s <= (C_CTR_3S-1) WHEN ctr_3s_rst_s = '1' ELSE ctr_3s_r - 1;                    -- REQ END: 38_39
        

   --------------------------------------------------------
   -- TLA EVENT GEN
   --------------------------------------------------------                               -- REQ START: 121  
   -- Brake Demand
   edge_detector_i1 : edge_detector 
   GENERIC MAP(
      G_EDGEPOLARITY          => '1'
   )
   PORT MAP(
      arst_i                  => arst_i, 
      clk_i                   => clk_i, 
      data_i                  => brk_dmnd_r_s, 
      edge_o                  => brk_dmnd_re_s, 
      valid_i                 => '1'
   );
      
   brk_dmnd_r_s <= brk_dmnd_r;

   -- Power Demand
   edge_detector_i2 : edge_detector 
   GENERIC MAP(
      G_EDGEPOLARITY          => '1'
   )
   PORT MAP(
      arst_i                  => arst_i, 
      clk_i                   => clk_i, 
      data_i                  => pwr_dmnd_r_s, 
      edge_o                  => pwr_dmnd_re_s, 
      valid_i                 => '1'
   );
   
   pwr_dmnd_r_s <= pwr_dmnd_r;                                                            -- REQ END: 121 

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   -- Only output one type of PWM TLA event to fix the PWM TLA event counter limit

   pwr_brk_dmnd_o    <= pwr_dmnd_re_s OR brk_dmnd_re_s;  -- Power Demand OR Brake Demand REQ 214 and REQ 121
   mc_no_pwr_o       <= mc_no_pwr_r;

   pwm0_fault_o      <= pwm0_fault_s;
   pwm1_fault_o      <= pwm1_fault_s;


END ARCHITECTURE beh;