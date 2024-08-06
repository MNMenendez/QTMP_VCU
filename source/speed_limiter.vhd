---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : speed_limiter.vhd
-- Module      : 25KM/H Speed Limit
-- Revision    : 1.14
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : 25km/h Speed Limiter
---------------------------------------------------------------
-- History :
-- Revision 1.14- May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.13- April 22, 2021
--    - NRibeiro: [CCN05] No new functionally added, spd_lim_override_valid_s signal added and logic
--                 was extracted from other internal process
-- Revision 1.12- April 19, 2021
--    - NRibeiro: [CCN05] Applied/Updated with CCN05 changes related to following Requirements:
--                 REQ 91_178_195_206_207
-- Revision 1.11- February 04, 2020
--    - NRibeiro: Code coverage improvements
-- Revision 1.10- January 28, 2020
--    - NRibeiro: Top level mux related to some out signals was moved to this module
-- Revision 1.9 - January 22, 2020
--    - NRibeiro: Fixed some output signal signals dependence with Inactive/Suppressed mode
-- Revision 1.8 - January 10, 2020
--    - NRibeiro: Fixing conditions for speed limit exceeded (de)assertion
-- Revision 1.7 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.6 - November 29, 2019
--    - NRibeiro: Applied CCN04 changes.
-- Revision 1.5 - March 22, 2019
--    - AFernandes: Applied CCN03 changes.
-- Revision 1.4 - July 27, 2018
--    - AFernandes: Applied code changes for CCN02 02.
-- Revision 1.3 - March 05, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.2 - February 27, 2018
--    - JMonteiro: Code adjustments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 29, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;


ENTITY speed_limiter IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i      : IN STD_LOGIC;   -- Internal 500ms synch pulse

      ----------------------------------------------------------------------------
      --  Speed Limit Function Request
      ----------------------------------------------------------------------------
      spd_lim_i         : IN STD_LOGIC;   -- Init Speed Limit function

      ----------------------------------------------------------------------------
      --  Speed Limit Override Function Request
      ----------------------------------------------------------------------------
      spd_lim_override_i: IN STD_LOGIC;   -- Speed Limit Override Request Input

      ----------------------------------------------------------------------------
      --  Speed Limit Exceeded Test Request
      ----------------------------------------------------------------------------
      spd_lim_exceed_tst_i: IN STD_LOGIC; -- Speed Limit Exceeded Test Request

      ----------------------------------------------------------------------------
      -- VCU operation mode
      ----------------------------------------------------------------------------
      test_mode_i       : IN STD_LOGIC;   -- Test operation mode
      suppressed_mode_i : IN STD_LOGIC;   -- Suppressed (Inactive) operation mode
      depressed_mode_i  : IN STD_LOGIC;   -- Depressed (Inhnibited) operation mode

      ----------------------------------------------------------------------------
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i         : IN STD_LOGIC;   -- Major Fault

      ----------------------------------------------------------------------------
      --  Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_h23kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i     : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange

      ----------------------------------------------------------------------------
      --  Zero Speed Input
      ----------------------------------------------------------------------------
      zero_spd_i        : IN STD_LOGIC;   -- Zero Speed Input

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      spd_lim_overridden_o : OUT STD_LOGIC; -- Speed Limit Overridden
      rly_out3_3V_o     : OUT STD_LOGIC;  -- Speed Limit Exceeded 2
      rly_out2_3V_o     : OUT STD_LOGIC;  -- Speed Limit Exceeded 1
      spd_lim_st_o      : OUT STD_LOGIC   -- Speed Limit Status Output

   );
END ENTITY speed_limiter;


ARCHITECTURE beh OF speed_limiter IS

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

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------

   -- 500 seconds for the Speed Limiter Timeout state (max value 1200 seconds) REQ: 95
   CONSTANT C_SPEED_LIMITER_TIMEOUT    : NATURAL := 500;

   -- 500 seconds counter
   CONSTANT C_CTR_500S                 : UNSIGNED(12 DOWNTO 0) := TO_UNSIGNED(C_SPEED_LIMITER_TIMEOUT * 2     , 13);   
   
   -- 1st 30 seconds
   CONSTANT C_CTR_470S                 : UNSIGNED(12 DOWNTO 0) := TO_UNSIGNED(C_SPEED_LIMITER_TIMEOUT * 2 - 60, 13);

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Input vectors
   SIGNAL spd_s                        : STD_LOGIC_VECTOR(5 DOWNTO 0);

   SIGNAL spd_lim_fsmctrl_r            : STD_LOGIC;
   SIGNAL spd_lim_fe_s                 : STD_LOGIC;

   SIGNAL spd_lim_exceed_r             : STD_LOGIC;
   SIGNAL spd_lim_exceed_r1            : STD_LOGIC;
   SIGNAL spd_lim_exceed_hist_r        : STD_LOGIC;

   SIGNAL ctr_timeout_s                : UNSIGNED(12 DOWNTO 0);
   SIGNAL ctr_timeout_r                : UNSIGNED(12 DOWNTO 0);
   SIGNAL ctr_timeout_en_s             : STD_LOGIC;
   SIGNAL ctr_timeout_load_r           : STD_LOGIC;

   SIGNAL spd_lim_st_r                 : STD_LOGIC;

   SIGNAL spd_lim_override_fe_s        : STD_LOGIC;
   SIGNAL spd_lim_overridden_r         : STD_LOGIC;
   SIGNAL spd_lim_overridden_latched_r : STD_LOGIC;
   SIGNAL spd_lim_overridden_pulse_r   : STD_LOGIC;
   SIGNAL spd_lim_override_valid_s     : STD_LOGIC;

   SIGNAL tms_spd_lim_stat_mux_s       : STD_LOGIC;
   SIGNAL tms_spd_lim_overridden_mux_s : STD_LOGIC;
   SIGNAL rly_out3_3V_mux_s            : STD_LOGIC;
   SIGNAL rly_out2_3V_mux_s            : STD_LOGIC;
   
   SIGNAL sup_or_dep_mode_s            : STD_LOGIC;

   -- zero speed logic
   TYPE spd_lim_st_typ IS (
                              SPDLIM_IDLE,
                              SPDLIM_WAIT_ZSPD,
                              SPDLIM_WAIT_NOT_ZSPD,
                              SPDLIM_BETWEEN_SPD_LIM_ACTIVE,
                              SPDLIM_SPD_LIM_ACTIVE,
                              SPDLIM_FAULT
                            );

   SIGNAL spd_lim_curst_r     : spd_lim_st_typ;

   attribute syn_encoding : string;
   attribute syn_encoding of spd_lim_st_typ : type is "johnson, safe";

BEGIN

   ----------------------------------------------------------------------------
   --  Speed Limit Overridden Output
   ----------------------------------------------------------------------------
   p_spd_lim_overridden_ld_f: PROCESS(clk_i, arst_i)              -- Indicator should actuate for 500ms. REQ: 208_212
   BEGIN
      IF (arst_i = '1') THEN
         spd_lim_overridden_pulse_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500ms_i = '1') THEN
            spd_lim_overridden_pulse_r    <= spd_lim_overridden_latched_r;
         END IF;
      END IF;
   END PROCESS p_spd_lim_overridden_ld_f;

   p_spd_lim_overridden_f: PROCESS(clk_i, arst_i)                 -- Generate Speed Limit Overridden 500ms pulse
   BEGIN
      IF (arst_i = '1') THEN
         spd_lim_overridden_latched_r    <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (sup_or_dep_mode_s = '1') THEN                        -- REQ: 137_206 Speed Limit Overridden is de-asserted
            spd_lim_overridden_latched_r <= '0';                  --   when in Inactive (Sup) or Inhibited (Dep) mode
         ELSIF (spd_lim_overridden_r = '1') THEN
            spd_lim_overridden_latched_r <= '1';
         ELSIF (pulse500ms_i = '1') THEN
            spd_lim_overridden_latched_r <= '0';
         END IF;
      END IF;
   END PROCESS p_spd_lim_overridden_f;

   --------------------------------------------------------
   -- MAX SPEED MONITOR
   --------------------------------------------------------
   p_spd_lim: PROCESS(clk_i, arst_i)                         -- REQ START: 139_169_170
   BEGIN                                                                   
      IF (arst_i = '1') THEN
         spd_lim_exceed_r1          <= '1';                  -- Active-low
      ELSIF RISING_EDGE(clk_i) THEN
         spd_lim_exceed_r1 <= not spd_lim_exceed_r;
      END IF;
   END PROCESS p_spd_lim;

   p_spd_lim_st: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         spd_lim_exceed_r           <= '0';                  -- NR: spd_lim_exceed_r is now active high
      ELSIF RISING_EDGE(clk_i) THEN
            IF (mjr_flt_i = '1') THEN                        -- REQ: 93: Permanently asserts spd limit
                 spd_lim_exceed_r   <= '1';                  --   exceed outputs if major fault occurs
            ELSIF (sup_or_dep_mode_s = '1') THEN             -- REQ: 137_206  [CCN05] de-asserted in both Supressed
                 spd_lim_exceed_r   <= '0';                  --   (Inactive) and Depressed (Inhibited) mode 
            ELSIF (ctr_timeout_en_s = '0')  THEN
                 spd_lim_exceed_r   <= '0';
            ELSIF (ctr_timeout_en_s = '1') THEN              -- [CCN05] If special rules dont apply, and Speed Limit
                 spd_lim_exceed_r   <= spd_lim_exceed_hist_r;--    ReguLation Timer is active, then this rule applies
            END IF;
      END IF;
   END PROCESS p_spd_lim_st;  
   
   
   -- [CCN05] Scenarios explicitly shows an VCU internal signal that
   --   corresponds to Speed >25Km/hr and does not depend of Supressed 
   --   (Inactive) or Depressed (Inhibited) mode. "spd_lim_exceed_hist_r"   
   --   is that signal.    
   p_spd_lim_exceed_hist: PROCESS(clk_i, arst_i)            
   BEGIN                                                    
      IF (arst_i = '1') THEN                                
         spd_lim_exceed_hist_r      <= '0';                 
      ELSIF RISING_EDGE(clk_i) THEN
         -- REQ: 213 Hysteresis
         IF ( (spd_lim_exceed_hist_r='0') AND OR_REDUCE(spd_s(spd_s'LEFT DOWNTO 1))='1') THEN      
            spd_lim_exceed_hist_r   <= '1';
         -- REQ: 213 Hysteresis   
         ELSIF ( (spd_lim_exceed_hist_r='1') AND OR_REDUCE(spd_s(spd_s'LEFT DOWNTO 0))='0' ) THEN  
            spd_lim_exceed_hist_r   <= '0';
         END IF;
      END IF;
   END PROCESS p_spd_lim_exceed_hist;                        -- REQ END: 139_169_170
   

   --------------------------------------------------------
   -- SPEED LIMIT FALLING DETECTOR
   --------------------------------------------------------
   
   edge_detector_i0 : edge_detector                                            -- REQ: 12,01       
   GENERIC MAP(
      G_EDGEPOLARITY       => '0'
   )         
   PORT MAP(
      arst_i               => arst_i, 
      clk_i                => clk_i, 
      data_i               => spd_lim_i, 
      edge_o               => spd_lim_fe_s, 
      valid_i              => '1'
   );   

   --------------------------------------------------------
   -- SPEED LIMIT OVERRIDE FALLING DETECTOR
   --------------------------------------------------------

   edge_detector_i1 : edge_detector                                            -- REQ: 91_207
   GENERIC MAP(
      G_EDGEPOLARITY       => '0'
   )
   PORT MAP(
      arst_i               => arst_i, 
      clk_i                => clk_i, 
      data_i               => spd_lim_override_i, 
      edge_o               => spd_lim_override_fe_s, 
      valid_i              => '1'
   );

   --[CCN05] When in Inactive (Suppressed) or Inhibited (Depressed) mode 
   --   VCU ignores speed limit override input. 4044 3101 r4, Scenario 7
   -- REQ: 207
   -- If "speed limit override input" valid, expires the timer 
   --   * only valid if not in Suppressed or Depressed mode
   --   * and only valid after 30 seconds REQ: 209 
   --   * and only valid if FSM is indicating that the  speed limit
   --      function is active
   spd_lim_override_valid_s <= '1'  when ((spd_lim_override_fe_s = '1') AND    
                                          (sup_or_dep_mode_s = '0')     AND    
                                          (ctr_timeout_r < C_CTR_470S)  AND    
                                          (spd_lim_fsmctrl_r = '1')  )  ELSE   
                               '0';                                            

   --------------------------------------------------------
   -- INPUT AGGREGATE
   --------------------------------------------------------
   spd_s <= spd_over_spd_i &
            spd_h110kmh_i  &
            spd_h90kmh_i   &
            spd_h75kmh_i   &
            spd_h25kmh_i   &
            spd_h23kmh_i;

   --------------------------------------------------------
   -- SPEED LIMIT STATUS OUTPUT
   --------------------------------------------------------
   p_spd_lim_stat: PROCESS(clk_i, arst_i)                                      -- REQ START: 195_199
   BEGIN
      IF (arst_i = '1') THEN
         spd_lim_st_r                     <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         if  (sup_or_dep_mode_s = '1') THEN                                    -- [CCN05] REQ 206
            spd_lim_st_r                  <= '0';
         else  
            spd_lim_st_r                  <= ctr_timeout_en_s ;                -- Asserted with speed timer
         end if;  
      END IF;
   END PROCESS p_spd_lim_stat;                                                 -- REQ END: 195_199

   --------------------------------------------------------
   --FSM for "speed limit mode" and sequence detection
   --------------------------------------------------------
   p_spd_lim_fsm: PROCESS(clk_i, arst_i)                                       -- REQ START: 91_195_210
      VARIABLE spd_lim_nxtst_v: spd_lim_st_typ;
   BEGIN

      IF (arst_i = '1') THEN
         spd_lim_curst_r                  <= SPDLIM_IDLE;
         spd_lim_nxtst_v                  := SPDLIM_IDLE;
         spd_lim_fsmctrl_r                <= '0';
         ctr_timeout_load_r               <= '0';

      ELSIF RISING_EDGE(clk_i) THEN

         IF (mjr_flt_i = '1') OR (spd_lim_curst_r = SPDLIM_FAULT) THEN
            spd_lim_nxtst_v               := SPDLIM_FAULT;
            spd_lim_fsmctrl_r             <= '0';
            ctr_timeout_load_r            <= '0'; 
         ELSE

            CASE spd_lim_curst_r is

               WHEN SPDLIM_WAIT_ZSPD =>
                  -- [CCN05] Default behaviour is maintain previous value
                  spd_lim_fsmctrl_r       <= spd_lim_fsmctrl_r;                   
                  ctr_timeout_load_r      <= '0';                     

                  IF (zero_spd_i = '1') THEN
                     spd_lim_nxtst_v      := SPDLIM_WAIT_NOT_ZSPD;
                  END IF;                 


               WHEN SPDLIM_WAIT_NOT_ZSPD =>                                      
                  -- [CCN05] Default behaviour is maintain previous value
                  spd_lim_fsmctrl_r       <= spd_lim_fsmctrl_r;                   
                  ctr_timeout_load_r      <= '0';                                      
                  IF (spd_lim_fe_s = '1') THEN
                     spd_lim_nxtst_v      := SPDLIM_WAIT_ZSPD;
                  ELSIF (zero_spd_i = '0') THEN 
                     spd_lim_nxtst_v      := SPDLIM_BETWEEN_SPD_LIM_ACTIVE;
                     ctr_timeout_load_r   <= '1';                     
                  END IF;                 


               WHEN SPDLIM_BETWEEN_SPD_LIM_ACTIVE =>               
                  -- [CCN05] In a 2nd Trip cock/Speed Limit input assertion during an  
                  --   period where the Speed Limit Timer was active in 4044 3101 r4, Scenario 4
                  --   the 'speed limit tms ouput' signal goes momentarly to low to indicate 
                  --   the re-start of the a new 'timer timout period' of 500 seconds
                  spd_lim_fsmctrl_r       <= '0';                                 
                  ctr_timeout_load_r      <= '1';                                 
                  spd_lim_nxtst_v         := SPDLIM_SPD_LIM_ACTIVE;               


               WHEN SPDLIM_SPD_LIM_ACTIVE =>
                  spd_lim_fsmctrl_r       <= '1';
                  ctr_timeout_load_r      <= '0'; 
                  IF ((spd_lim_fe_s = '1') AND (sup_or_dep_mode_s = '0')) THEN    
                     -- [CCN05] When in Inactive (Supressed) or Inhibited (Depressed) mode
                     --    VCU ignores 2nd Trip cock/Speed Limit input. 4044 3101 r4, Scenario 11
                     spd_lim_nxtst_v      := SPDLIM_WAIT_ZSPD;                    
                  ELSIF (ctr_timeout_r = 0) THEN
                     spd_lim_nxtst_v      := SPDLIM_IDLE;
                  ELSIF (spd_lim_override_valid_s = '1' ) THEN                    
                     -- if speed limit override valid, expires this state         -- REQ: 207
                        spd_lim_nxtst_v := SPDLIM_IDLE;
                  END IF;


               WHEN OTHERS =>             --  SPDLIM_IDLE                         
                  -- Includes SPDLIM_IDLE and SPDLIM_FAULT, but when in SPDLIM_FAULT never
                  --    enters this condition due to 1st IF condition on line 339
                  spd_lim_fsmctrl_r       <= '0';                                 
                  ctr_timeout_load_r      <= '0'; 
                  IF ((spd_lim_fe_s = '1') AND (sup_or_dep_mode_s = '0')) THEN
                  -- [CCN05] When in Inactive (Supressed) or Inhibited (Depressed) mode
                  --    VCU ignores Trip cock/Speed Limit input. 4044 3101 r4, Scenario 9
                     spd_lim_nxtst_v      := SPDLIM_WAIT_ZSPD;                    
                  END IF;

                  
            END CASE;
         END IF;
         spd_lim_curst_r                  <= spd_lim_nxtst_v;                     -- Next state clocked into register
            
      END IF;
   END PROCESS p_spd_lim_fsm;                                                     -- REQ END: 91_195

   --------------------------------------------------------
   -- 500 SECONDS COUNTER
   --------------------------------------------------------
   p_spd_lim_timer: PROCESS(clk_i, arst_i)                                        -- Speed Limit Timer REQ: 178.
   BEGIN
      IF (arst_i = '1') THEN
         ctr_timeout_r          <= (OTHERS => '0');
         spd_lim_overridden_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         spd_lim_overridden_r   <= '0';
         IF (ctr_timeout_load_r = '1') THEN 
            -- Load Initial value to start counting (decrementing) again
            ctr_timeout_r       <= C_CTR_500S;
         ELSIF (spd_lim_override_valid_s = '1') THEN
            -- If speed limit override valid, expires the timer                   --  REQ: 207
            -- REQ 210: the counter is expired, but the detection of the  
            --   sequences to enter in a new "Speed Limit mode" is totally
            --   independent (above FSM) from this process here.            
            ctr_timeout_r       <= (OTHERS => '0');                              
            spd_lim_overridden_r <= '1';                                      
                                                                                  
         ELSIF (pulse500ms_i = '1') AND (spd_lim_fsmctrl_r = '1') THEN
            -- Load next value: 
            --   Either (ctr_timeout_r - 1) if "speed limit mode" is active,
            --   Or     (ctr_timeout_r )    if "speed limit mode" is not active
            ctr_timeout_r    <= ctr_timeout_s;                                    
         END IF;                                                                  
      END IF;                                                                     
   END PROCESS p_spd_lim_timer;                                                   
   
   -- Next value for Speed Limit Timer REQ: 178.
   ctr_timeout_s                <= ctr_timeout_r - 1 WHEN (ctr_timeout_en_s = '1') ELSE 
                                   ctr_timeout_r;

   ctr_timeout_en_s             <= '1' when (spd_lim_fsmctrl_r = '1') AND (ctr_timeout_r /= 0) else '0';

   --------------------------------------------------------
   -- Signal Multiplexing
   --------------------------------------------------------
   -- NR (2020/01/22): When VCU is in Test opmode, the speed limit output signals are de-asserted, except for the case
   --    where the VCU state is in "Speed Limit Test" where the "Speed Limit Exceeded" output signals must be asserted.
   -- REQ: 106
   tms_spd_lim_overridden_mux_s <= '0'                        when (test_mode_i ='1') else spd_lim_overridden_pulse_r;
   rly_out3_3V_mux_s            <= (not spd_lim_exceed_tst_i) when (test_mode_i ='1') else spd_lim_exceed_r1;
   rly_out2_3V_mux_s            <= (not spd_lim_exceed_tst_i) when (test_mode_i ='1') else spd_lim_exceed_r1;
   tms_spd_lim_stat_mux_s       <= '0'                        when (test_mode_i ='1') else spd_lim_st_r;


   --------------------------------------------------------
   -- Inactive OR Inhibited mode detection 
   -------------------------------------------------------- 
   sup_or_dep_mode_s            <= suppressed_mode_i OR depressed_mode_i;         -- [CCN05] REQ: 206
   
   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   spd_lim_overridden_o         <= tms_spd_lim_overridden_mux_s;
   rly_out3_3V_o                <= rly_out3_3V_mux_s;
   rly_out2_3V_o                <= rly_out2_3V_mux_s;
   spd_lim_st_o                 <= tms_spd_lim_stat_mux_s;                        -- REQ: 199

END ARCHITECTURE beh;