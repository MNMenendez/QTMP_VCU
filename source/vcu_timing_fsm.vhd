---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : vcu_timing_fsm.vhd
-- Module      : VCU Timing System
-- Revision    : 1.13
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : VCU Timing System FSM: Implements both Normal
--               and Depressed modes.
---------------------------------------------------------------
-- History :
-- Revision 1.13- May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.12- April 30, 2021
--    - NRibeiro: [CCN05] Fix: when leaving Inactive mode No Warning State, transition should be noted.
-- Revision 1.11- April 16, 2021
--    - NRibeiro: [CCN05] Applied/Updated with CCN05 changes related to following Requirements:
--                REQ 106_61_115_56_118_141_214. 
-- Revision 1.10- February 04, 2020
--    - NRibeiro: Code coverage improvements.
-- Revision 1.9 - January 10, 2020
--    - NRibeiro: Fixing entering Test mode from "No Warning" and "2nd Stage Warning"
-- Revision 1.8 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.7 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes.
-- Revision 1.6 - April 15, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.5 - July 23, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.4 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.3 - March 08, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.2 - February 27, 2018
--    - JMonteiro: Code adjustments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 17, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;

ENTITY vcu_timing_fsm IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i      : IN STD_LOGIC;                        -- Internal 500ms synch pulse
      pulse500us_i      : IN STD_LOGIC;                        -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  Decision Inputs
      ----------------------------------------------------------------------------
      tla_i             : IN STD_LOGIC_VECTOR(7 DOWNTO 0);     -- Aggregated Task Linked Activity
      spd_i             : IN STD_LOGIC_VECTOR(7 DOWNTO 0);     -- Aggregated speed signals
      opmode_i          : IN STD_LOGIC_VECTOR(4 DOWNTO 0);     -- Current Operation Mode

      vigi_pb_i         : IN STD_LOGIC;                        -- Vigilance Push Button
      vigi_pb_hld_i     : IN STD_LOGIC;                        -- Vigilance Push Button Held (internal)

      zero_spd_i        : IN STD_LOGIC;                        -- Zero Speed Input
      cab_act_i         : IN STD_LOGIC;                        -- Cab Ative
      spd_err_i         : IN STD_LOGIC;                        -- Analog Speed Error (OPL ID#40)
      mc_no_pwr_i       : IN STD_LOGIC;                        -- MC = No Power

      vcu_tmr_hlt_i     : IN STD_LOGIC;                        -- Halt VCU FSM

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      vis_warn_stat_o   : OUT STD_LOGIC;                       -- Visible Warning Status
      light_out_o       : OUT STD_LOGIC;                       -- Flashing Light
      buzzer_o          : OUT STD_LOGIC;                       -- Buzzer
      penalty1_out_o    : OUT STD_LOGIC;                       -- Penalty Brake 1
      penalty2_out_o    : OUT STD_LOGIC;                       -- Penalty Brake 2
      rly_out1_3V_o     : OUT STD_LOGIC;                       -- Radio Warning Relay
      st_notst_o        : OUT STD_LOGIC;                       -- Inhibit transition to Test Mode      
      st_nosup_o        : OUT STD_LOGIC;                       -- Inhibit transition to Suppression Mode
      st_nonrm_o        : OUT STD_LOGIC;                       -- Inhibit transition from Depressed to Normal Mode
      st_1st_wrn_o      : OUT STD_LOGIC;                       -- Indicate VCU in 1st Warning (for Diag)
      st_2st_wrn_o      : OUT STD_LOGIC;                       -- Indicate VCU in 2st Warning (for Diag)
      vcu_rst_o         : OUT STD_LOGIC;                       -- VCU RST (for TMS)

      tmod_xt_o         : OUT STD_LOGIC;                       -- Test Mode Exit
      opmode_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);    -- NR: This is now the oficial OPMODE
      spd_lim_exceed_tst_o : OUT STD_LOGIC                      -- Test Mode Exit
   );
END ENTITY vcu_timing_fsm;


ARCHITECTURE beh OF vcu_timing_fsm IS

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
   -- TYPES
   --------------------------------------------------------
   TYPE T_TLA_CTR IS ARRAY (7 DOWNTO 0) OF UNSIGNED(3 DOWNTO 0);    -- CCN03
   TYPE T_EVT_REM IS ARRAY (7 DOWNTO 0) OF STD_LOGIC_VECTOR(7 DOWNTO 0);


   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------
   -- No Warning State Timer Init
   CONSTANT C_NOWR_LT3KMH     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(90000-1,17);     -- Ctr for speed < 3km/h
   CONSTANT C_NOWR_HT3KMH     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(90000-1,17);     -- Ctr for speed > 3km/h
   CONSTANT C_NOWR_HT23KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(90000-1,17);     -- Ctr for speed > 23km/h
   CONSTANT C_NOWR_HT25KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(90000-1,17);     -- Ctr for speed > 25km/h
   CONSTANT C_NOWR_HT75KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(70000-1,17);     -- Ctr for speed > 75km/h
   CONSTANT C_NOWR_HT90KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(60000-1,17);     -- Ctr for speed > 90km/h
   CONSTANT C_NOWR_HT110KMH   : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(50000-1,17);     -- Ctr for speed > 100km/h
   CONSTANT C_NOWR_OVRSPD     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(50000-1,17);     -- Ctr for speed Overrange

   -- 1st Stage Warning State Timer Init
   CONSTANT C_1STWRN_INIT     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(10000-1,17);

   -- 2nd Stage Warning State Timer Init
   CONSTANT C_2STW_LT3KMH     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(20000-1,17);     -- Ctr for speed < 3km/h
   CONSTANT C_2STW_HT3KMH     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(20000-1,17);     -- Ctr for speed > 3km/h
   CONSTANT C_2STW_HT23KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(20000-1,17);     -- Ctr for speed > 23km/h
   CONSTANT C_2STW_HT25KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(20000-1,17);     -- Ctr for speed > 25km/h
   CONSTANT C_2STW_HT75KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(20000-1,17);     -- Ctr for speed > 75km/h
   CONSTANT C_2STW_HT90KMH    : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(10000-1,17);     -- Ctr for speed > 90km/h
   CONSTANT C_2STW_HT110KMH   : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(10000-1,17);     -- Ctr for speed > 100km/h
   CONSTANT C_2STW_OVRSPD     : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(10000-1,17);     -- Ctr for speed Overrange

   -- Depressed State Timer Init
   CONSTANT C_DPRSD_INIT      : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(60000-1,17);

   -- Brake Application No Reset (Error) State Timer Init
   CONSTANT C_BRNR_INIT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(90000-1,17);

   -- Normal Permanent Light Reset Allowed State Timer Init
   CONSTANT C_NRML_INIT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(60000-1,17);

   -- Train Stopped No Reset State Timer Init
   CONSTANT C_TSNR_INIT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(6000-1,17);

   -- Counter Cab Init for Normal State
   CONSTANT C_CAB_INIT        : UNSIGNED(11 DOWNTO 0) := TO_UNSIGNED(4000-1,12);

   -- Park Brake Timer Init
   CONSTANT C_PBRK_INIT       : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED(1000-1,10);

   -- Radio Warning Timer
   CONSTANT C_RDWR_INIT       : UNSIGNED(16 DOWNTO 0) := TO_UNSIGNED(60000-1,17);     -- 1 min

   -- VCU Reset TLA Event Counters:
   CONSTANT C_TLA_CTR : T_TLA_CTR := ( TO_UNSIGNED(15,4), TO_UNSIGNED(15,4), TO_UNSIGNED(15,4), TO_UNSIGNED(15,4),
                                       TO_UNSIGNED(1,4),  TO_UNSIGNED(1,4),  TO_UNSIGNED(15,4), TO_UNSIGNED(1,4));


   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Operation Mode FSM
   TYPE   vcut_st_typ IS ( VCUT_IDLE,                                -- Idle
                           VCUT_NO_WARNING,                          -- No Warning
                           VCUT_1ST_WARNING,                         -- 1st Stage Warning
                           VCUT_2ST_WARNING,                         -- 2nd Stage Warning
                           VCUT_BRK_NORST,                           -- Brake Application No Reset
                           VCUT_BRK_NORST_ERR,                       -- Brake Application No Reset Error
                           VCUT_TRN_STOP_NORST,                      -- Train Stopped No Reset
                           VCUT_NORMAL,                              -- Normal Permanent Light Reset Allowed
                           VCUT_DEPRESSED,                           -- Depressed Permanent Light Reset Allowed
                           VCUT_SPD_LIMIT_TEST                       -- Speed Limit Test
                        );

   attribute syn_encoding : string;
   attribute syn_encoding of vcut_st_typ : type is "johnson, safe";

   SIGNAL vcut_curst_r        : vcut_st_typ;
   SIGNAL vcut_nxtst_s        : vcut_st_typ;

   SIGNAL vcut_st_hld_s       : vcut_st_typ;
   SIGNAL vcut_st_hld_r       : vcut_st_typ;                         -- Hold state to restore after Test or Sup modes

   -- Operation Mode
   SIGNAL opmode_r            : STD_LOGIC_VECTOR(4 DOWNTO 0);

   SIGNAL st_notst_s          : STD_LOGIC;
   SIGNAL st_notst_r          : STD_LOGIC;   
   SIGNAL st_nosup_s          : STD_LOGIC;
   SIGNAL st_nosup_r          : STD_LOGIC;
   SIGNAL st_nonrm_s          : STD_LOGIC;
   SIGNAL st_nonrm_r          : STD_LOGIC;
   SIGNAL st_1st_wrn_s        : STD_LOGIC;
   SIGNAL st_1st_wrn_r        : STD_LOGIC;
   SIGNAL st_2st_wrn_s        : STD_LOGIC;
   SIGNAL st_2st_wrn_r        : STD_LOGIC;

   -- TLA
   SIGNAL tla_re_s            : STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL tla_diff_0_r        : STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL tla_diff_1_r        : STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL tla_diff_2_r        : STD_LOGIC;
   SIGNAL tla_evt_ctr_r       : T_TLA_CTR;

   -- ACK
   SIGNAL ack_s               : STD_LOGIC_VECTOR(0 DOWNTO 0);
   SIGNAL ack_re_s            : STD_LOGIC_VECTOR(0 DOWNTO 0);
   SIGNAL ack_diff_0_r        : STD_LOGIC_VECTOR(0 DOWNTO 0);
   SIGNAL ack_diff_1_r        : STD_LOGIC_VECTOR(0 DOWNTO 0);

   -- VPB Hold Detectors                                            -- VPB Hold Detectors
   SIGNAL vpb_valid_s         : STD_LOGIC_VECTOR(0 DOWNTO 0);       --

   -- Timers
   SIGNAL init_tmr_s          : STD_LOGIC;                           -- Initialize Timer
   SIGNAL timer_ctr_r         : UNSIGNED(16 DOWNTO 0);               -- Max value 90000
   SIGNAL timer_ctr_s         : UNSIGNED(16 DOWNTO 0);
   SIGNAL timer_ctr_init_s    : UNSIGNED(16 DOWNTO 0);               -- Max value 90000

   SIGNAL init_ctmr_s         : STD_LOGIC;                           -- Initialize Cab Timer
   SIGNAL ctmr_ctr_r          : UNSIGNED(11 DOWNTO 0);               -- Max value 6000
   SIGNAL ctmr_ctr_s          : UNSIGNED(11 DOWNTO 0);

   -- VCU Timer Init
   SIGNAL tmr_init_nowr_s     : UNSIGNED(16 DOWNTO 0);
   SIGNAL tmr_init_1stw_s     : UNSIGNED(16 DOWNTO 0);
   SIGNAL tmr_init_2stw_s     : UNSIGNED(16 DOWNTO 0);
   SIGNAL tmr_init_dprs_s     : UNSIGNED(16 DOWNTO 0);
   SIGNAL tmr_init_brnr_s     : UNSIGNED(16 DOWNTO 0);
   SIGNAL tmr_init_nrml_s     : UNSIGNED(16 DOWNTO 0);
   SIGNAL tmr_init_trst_s     : UNSIGNED(16 DOWNTO 0);

   -- Test Mode
   SIGNAL tmod_xt_s           : STD_LOGIC;
   SIGNAL tmod_xt_re_s        : STD_LOGIC;
   SIGNAL tmod_end_s          : STD_LOGIC;
   SIGNAL tmod_st_inc_r       : STD_LOGIC;
   SIGNAL tmod_init_s         : STD_LOGIC;

   -- Supress Mode
   SIGNAL supmod_xt_s         : STD_LOGIC;
   
   -- Supress Mode
   SIGNAL depmod_xt_s         : STD_LOGIC;

   -- Radio Warning
   SIGNAL radio_ctr_s         : UNSIGNED(16 DOWNTO 0);
   SIGNAL radio_ctr_r         : UNSIGNED(16 DOWNTO 0);
   SIGNAL radio_0_s           : STD_LOGIC;
   SIGNAL radio_1_s           : STD_LOGIC;
   SIGNAL radio_r             : STD_LOGIC;
   SIGNAL t6_tmr_en_s         : STD_LOGIC;
   SIGNAL t6_tmr_en_mod_s     : STD_LOGIC;

   -- Output Alarms
   SIGNAL flash_light_s       : STD_LOGIC;
   SIGNAL solid_light_s       : STD_LOGIC;

   -- Penalty Brake
   SIGNAL penalty1_out_s      : STD_LOGIC;
   SIGNAL penalty1_out_0_s    : STD_LOGIC;
   SIGNAL penalty1_out_r      : STD_LOGIC;

   SIGNAL penalty2_out_s      : STD_LOGIC;
   SIGNAL penalty2_out_0_s    : STD_LOGIC;
   SIGNAL penalty2_out_r      : STD_LOGIC;

   -- Buzzer
   SIGNAL buzzer_0_s          : STD_LOGIC;
   SIGNAL buzzer_1_s          : STD_LOGIC;
   SIGNAL buzzer_r            : STD_LOGIC;

   -- Warning Light
   SIGNAL light_stat_out_s    : STD_LOGIC;
   SIGNAL light_stat_out_r    : STD_LOGIC;
   SIGNAL light_out_0_s       : STD_LOGIC;
   SIGNAL light_out_1_s       : STD_LOGIC;
   SIGNAL light_out_r         : STD_LOGIC;
   SIGNAL fl_light_s          : STD_LOGIC;
   SIGNAL fl_light_r          : STD_LOGIC;

   -- VCU No Warninf State
   SIGNAL vsu_nowrn_s         : STD_LOGIC;

   -- VCU Reset
   SIGNAL vcu_rst_0_s         : STD_LOGIC;
   SIGNAL vcu_rst_1_s         : STD_LOGIC;
   SIGNAL vcu_rst_0_r         : STD_LOGIC;
   SIGNAL vcu_rst_1_r         : STD_LOGIC;
   --SIGNAL vsu_rst_prst_r    : STD_LOGIC;

   SIGNAL spd_lim_exceed_tst_r : STD_LOGIC;
   SIGNAL spd_lim_exceed_tst_s : STD_LOGIC;

BEGIN

   ----------------------------------------------------------------------------
   --  VCU TIMING FSM
   ----------------------------------------------------------------------------
   -- Clocked state transition
   p_vcut_fsm_st: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         vcut_curst_r   <= VCUT_IDLE;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            vcut_curst_r   <= vcut_nxtst_s;
         END IF;
      END IF;
   END PROCESS p_vcut_fsm_st;

   -- VCU Timing FSM
   p_vcut_fsm: PROCESS(vcut_curst_r, opmode_r, tla_diff_2_r, timer_ctr_r, vigi_pb_hld_i, depmod_xt_s,
                       vpb_valid_s, spd_err_i, tmr_init_1stw_s, tmr_init_nowr_s, zero_spd_i, spd_i,
                       cab_act_i, ctmr_ctr_r,mc_no_pwr_i, tmod_xt_s, tmod_st_inc_r, tmr_init_2stw_s, vcut_st_hld_r,
                       tmr_init_brnr_s, tmr_init_dprs_s, tmr_init_trst_s, tmr_init_nrml_s, supmod_xt_s, tmod_init_s)
   BEGIN
      vcut_nxtst_s                     <= vcut_curst_r;
      timer_ctr_init_s                 <= timer_ctr_r;
      init_tmr_s                       <= '0';
      init_ctmr_s                      <= '0';
      buzzer_0_s                       <= '0';
      flash_light_s                    <= '0';
      solid_light_s                    <= '0';
      radio_0_s                        <= '0';
      penalty1_out_s                   <= '0';
      penalty2_out_s                   <= '0';
      st_nosup_s                       <= '0';
      st_nonrm_s                       <= '0';                       -- Avoids opmode_fsm to jump to normal or 
                                                                     --   depressed when this FSM was still not updated
      vsu_nowrn_s                      <= '0';
      t6_tmr_en_s                      <= '0';
      tmod_end_s                       <= '0';
      st_1st_wrn_s                     <= '0';
      st_2st_wrn_s                     <= '0';
      spd_lim_exceed_tst_s             <= '0';

      CASE vcut_curst_r IS                                           -- REQ START: 117

         -- WHEN VCUT_IDLE =>                                        -- VCUT_IDLE state is part of "WHEN OTHERS =>"

         WHEN VCUT_NO_WARNING =>
            vsu_nowrn_s                <= '1';                       -- VCU is in No Warning State
            solid_light_s              <= '0';
            radio_0_s                  <= '0';                       -- Release Gateway Alarm
            penalty1_out_s             <= '0';                       -- Release Penalty Brake
            penalty2_out_s             <= '0';

            IF (tla_diff_2_r = '1') THEN                             -- REQ: 112_117 (Detect TLA Activity)
               init_tmr_s              <= '1';                       -- Reset VCU Timer
               init_ctmr_s             <= '1';                       -- Reset CAB Timer (4000)
               vsu_nowrn_s             <= '0';                       -- Reset counter when jumps to No Warning for TMS
               timer_ctr_init_s        <= tmr_init_nowr_s;
            END IF;

            IF (tmod_init_s = '1') THEN                              -- If entering the test mode
               vcut_nxtst_s            <= VCUT_1ST_WARNING;          --   Jump to VCUT_1ST_WARNING          
            ELSIF (supmod_xt_s = '1') THEN                           -- If suppressed (inactive) mode exiting   
                                                                     --    [CCN05] REQ: 115_56_118  
               init_tmr_s              <= '1';                       --    Reset timer for No Warning stage
               timer_ctr_init_s        <= tmr_init_nowr_s;           --    and reports transition to No Warning
               vsu_nowrn_s             <= '0';                       -- 
               vcut_nxtst_s            <= VCUT_NO_WARNING;           --    Jump to VCUT_NO_WARNING
            ELSIF ( (timer_ctr_r = 0)    OR                          -- If T1 (TLA Activity) Expired or
                 (vigi_pb_hld_i = '1') ) THEN                        --    VPB Signal Held      > 1.5s
               init_tmr_s              <= '1';                       --    Reset VCU Timers
               timer_ctr_init_s        <= tmr_init_1stw_s;           --    VCU Timer = 10000
               vcut_nxtst_s            <= VCUT_1ST_WARNING;          --    Jump to VCUT_1ST_WARNING
            END IF;

         WHEN VCUT_1ST_WARNING =>
            st_1st_wrn_s               <= '1';                       -- REQ 180. Indicate state to Diag IF.
            flash_light_s              <= '1';                       -- 1st Stage Warnings

            IF (opmode_r = "01000")       THEN                       -- REQ: 106_107
               st_nonrm_s              <= '1';
               IF (tmod_xt_s = '1') THEN                             -- If Test mode exiting
                  vcut_nxtst_s         <= vcut_st_hld_r;             --    restores previous state [CCN05] REQ 61
               ELSIF (tmod_st_inc_r = '1')   THEN                    -- If transition condition met (in Test Mode)
                  vcut_nxtst_s         <= VCUT_2ST_WARNING;          --    progresses to the next test state
               END IF;
            ELSIF (supmod_xt_s = '1') THEN                           -- If suppressed (inactive) mode exiting   
                                                                     --    [CCN05] REQ: 115_56_118 
               init_tmr_s              <= '1';                       --    Reset timer for No Warning stage
               timer_ctr_init_s        <= tmr_init_nowr_s;
               vcut_nxtst_s            <= VCUT_NO_WARNING;           --    Jump to VCUT_NO_WARNING
            ELSIF (timer_ctr_r = 0 )   THEN                          -- If T2 Expired (5 secs)
                     init_tmr_s        <= '1';                       --    Reset VCU Timers
                     timer_ctr_init_s  <= tmr_init_2stw_s;           --    VCU Timer init depends on speed reading
                     vcut_nxtst_s      <= VCUT_2ST_WARNING;          --    Jump to VCUT_2ST_WARNING
            ELSIF (vpb_valid_s(0) = '1') THEN                        -- If ACK VPB pressed
                     init_tmr_s        <= '1';                       --    Reset timer for No Warning stage
                     timer_ctr_init_s  <= tmr_init_nowr_s;
                     vcut_nxtst_s      <= VCUT_NO_WARNING;           --    Jump to VCUT_NO_WARNING
            ELSIF (tla_diff_2_r = '1') THEN                          -- IF (Detect TLA Activity) REQ: 112_117 
                     init_tmr_s        <= '1';                       --    Reset VCU Timer
                     timer_ctr_init_s  <= tmr_init_nowr_s;
                     vcut_nxtst_s      <= VCUT_NO_WARNING;           -- Jump to VCUT_NO_WARNING
            END IF;

         WHEN VCUT_2ST_WARNING =>
            st_2st_wrn_s               <= '1';                       -- REQ 180. Indicate state to Diag IF
            flash_light_s              <= '1';                       -- 2nd Stage Warnings
            buzzer_0_s                 <= '1';

            IF (opmode_r = "01000")       THEN                       -- REQ: 106_107
               st_nonrm_s              <= '1';
               IF (tmod_xt_s = '1') THEN                             -- If Test mode exiting
                  vcut_nxtst_s         <= vcut_st_hld_r;             --    restores previous state [CCN05] REQ 61
               ELSIF (tmod_st_inc_r = '1')   THEN                    -- If transition condition met (in Test Mode)
                  vcut_nxtst_s         <= VCUT_SPD_LIMIT_TEST;       --    progresses to the next test state
               END IF;
            ELSIF (tmod_init_s = '1') THEN                           -- If entering the test mode
               vcut_nxtst_s            <= VCUT_1ST_WARNING;          --   Jump to VCUT_1ST_WARNING
            ELSIF (supmod_xt_s = '1') THEN                           -- If suppressed (inactive) mode exiting   
                                                                     --    [CCN05] REQ 115_56_118 
               init_tmr_s              <= '1';                       --    Reset timer for No Warning stage  
               timer_ctr_init_s        <= tmr_init_nowr_s;
               vcut_nxtst_s            <= VCUT_NO_WARNING;           --    Jump to VCUT_NO_WARNING
            ELSIF ( (timer_ctr_r = 0)       AND                      -- If T3 Expired (5 secs) AND  -- REQs: 112
                    (opmode_r = "00100") )  THEN                     -- Current Operation Mode is Depressed
               init_tmr_s              <= '1';                       --    Reset VCU Timer
               t6_tmr_en_s             <= '1';                       --    REQ: 62 (Radio Warning Timer Enable)
               init_ctmr_s             <= '1';                       --    Reset CAB Timer (4000)
               timer_ctr_init_s        <= tmr_init_dprs_s;           --    VCU Timer = 60000
               vcut_nxtst_s            <= VCUT_DEPRESSED;            --    Jump to VCUT_DEPRESSED
            ELSIF ( (timer_ctr_r = 0)      AND                       -- If T3 Expired (5 secs) AND
                 (opmode_r = "00001") ) THEN                         -- Current Operation Mode is Normal
               init_tmr_s              <= '1';                       --    Reset VCU Timer
               timer_ctr_init_s        <= tmr_init_brnr_s;           --    VCU Timer = 90000 (OPL ID#38)
               vcut_nxtst_s            <= VCUT_BRK_NORST;
            ELSIF (vpb_valid_s(0) = '1') THEN                        -- IF ACK VPB is valid
               init_tmr_s              <= '1';                       --    Reset tmr for No Warning 
               timer_ctr_init_s        <= tmr_init_nowr_s;
               vcut_nxtst_s            <= VCUT_NO_WARNING;           --    Jump to VCUT_NO_WARNING
            ELSIF (tla_diff_2_r = '1') THEN                          -- If Detect TLA Activity (REQ: 112_117)
               init_tmr_s              <= '1';                       --    Reset VCU Timer
               timer_ctr_init_s        <= tmr_init_nowr_s;
               vcut_nxtst_s            <= VCUT_NO_WARNING;           --    Jump to VCUT_NO_WARNING
            END IF;

         WHEN VCUT_SPD_LIMIT_TEST =>
            flash_light_s              <= '1';                       -- [CCN05] REQ 106 and REQ 141 
            st_nonrm_s                 <= '1';
            spd_lim_exceed_tst_s       <= '1';
            IF (tmod_xt_s = '1') THEN                                -- If Test mode exiting
               vcut_nxtst_s            <= vcut_st_hld_r;             --    restores previous state [CCN05] REQ 61
            ELSIF (tmod_st_inc_r = '1')   THEN                       -- If transition condition met (in Test Mode)
               vcut_nxtst_s            <= VCUT_NORMAL;               --    progresses to the next test state
            END IF;

         WHEN VCUT_BRK_NORST =>
            flash_light_s              <= '1';
            penalty1_out_s             <= '1';
            penalty2_out_s             <= '1';
            st_nosup_s                 <= '1';                       -- REQ: 52.01 (Block transition to Sup mode)

            IF (spd_err_i = '1') THEN
               vcut_nxtst_s   <= VCUT_BRK_NORST_ERR;                 -- Jump to VCUT_BRK_NORST_ERR. Timer should not be
                                                                     -- initialized here (OPL ID#38)
            ELSIF ((zero_spd_i = '1')    AND                         -- Digital Speed Detected
                   (spd_i = "00000001") )THEN                        -- Analog Speed = 1 (0-3km/h)
                     init_tmr_s        <= '1';                       -- Reset VCU Timer
                     timer_ctr_init_s  <= tmr_init_trst_s;           -- VCU Timer = 6000
                     vcut_nxtst_s      <= VCUT_TRN_STOP_NORST;       -- Jump to VCUT_TRN_STOP_NORST
            END IF;

         WHEN VCUT_BRK_NORST_ERR =>
            flash_light_s              <= '1';
            penalty1_out_s             <= '1';
            penalty2_out_s             <= '1';
            st_nosup_s                 <= '1';                       -- REQ: 52 (Block transition to Sup mode)

            IF (timer_ctr_r = 0) THEN                                -- Simply waits and bypasses TRN_STOP state
               init_tmr_s              <= '1';                       --    Reset VCU Timer
               timer_ctr_init_s        <= tmr_init_nrml_s;           --    VCU Timer = 60000
               t6_tmr_en_s             <= '1';                       --    REQ: 62 (Radio Warning Timer Enable)
               vcut_nxtst_s            <= VCUT_NORMAL;               --    Jump to VCUT_NORMAL
            END IF;

         WHEN VCUT_TRN_STOP_NORST =>
            flash_light_s              <= '1';
            penalty1_out_s             <= '1';
            penalty2_out_s             <= '1';
            st_nosup_s                 <= '1';                       -- REQ: 52.02 (Block transition to Sup mode)

            IF (timer_ctr_r = 0) THEN                                -- VCU Timer Elapsed
               init_tmr_s              <= '1';                       -- Reset VCU Timer
               init_ctmr_s             <= '1';                       -- Reset CAB Timer (4000)
               timer_ctr_init_s        <= tmr_init_nrml_s;           -- VCU Timer = 60000
               t6_tmr_en_s             <= '1';                       -- REQ: 62 (Radio Warning Timer Enable)
               vcut_nxtst_s            <= VCUT_NORMAL;               -- Jump to VCUT_NORMAL
            END IF;

         WHEN VCUT_NORMAL =>
            solid_light_s              <= '1';
            penalty1_out_s             <= '1';
            penalty2_out_s             <= '1';
            st_nosup_s                 <= '1';                       -- REQ: 52.03 (Block transition to Sup mode)
            radio_0_s                  <= '1';                       -- Enable Radio Wrn if Radio Timer Expires
            IF (cab_act_i = '0') THEN                                -- If CAB is active
               init_ctmr_s             <= '1';                       --   Reset CAB Timer (4000)
            END IF;

            IF (opmode_r = "01000")       THEN                       -- REQs: 106_107
               st_nonrm_s              <= '1';
               radio_0_s               <= '0';                       -- Disable Radio warning when in Test Mode
               IF (tmod_xt_s = '1') THEN                             -- If Test mode exiting
                  vcut_nxtst_s         <= vcut_st_hld_r;             --    restores previous state
               ELSIF (tmod_st_inc_r = '1')   THEN                    -- Don't evaluate other conditions if in test mode
                  tmod_end_s           <= '1';                       --    halted when entering Test Mode.
               END IF;
            ELSIF ((mc_no_pwr_i = '1')  AND                          -- IF MC = No Power (5% <= pwm_ctr <= 18.89%) AND
                    (((cab_act_i = '1') AND (ctmr_ctr_r = 0)) OR     -- Cab not active and cab timer elapsed AND 
                      (vpb_valid_s(0) = '1'))) THEN                  -- ACK VPB is valid
                        init_tmr_s     <= '1';                       --  Reset tmr for No Warning (re-count TLA events)
                        timer_ctr_init_s <= tmr_init_nowr_s;
                        vcut_nxtst_s   <= VCUT_NO_WARNING;           --  Jump to VCUT_NO_WARNING
            END IF;

         WHEN VCUT_DEPRESSED =>
            solid_light_s              <= '1';
            st_nosup_s                 <= '1';                       -- REQ: 52 (Block transition to Sup mode)
            radio_0_s                  <= '1';                       -- Enable Gateway Warning (Radio Timer Expires)
            IF (cab_act_i = '0') THEN                                -- If CAB is active
               init_ctmr_s             <= '1';                       --    Reset CAB Timer (4000)
            END IF;
            
            IF (depmod_xt_s = '1') THEN                              -- IF mode restored to Normal (REQ: 51)
                  init_tmr_s           <= '1';                       --    Reset VCU Timer
                  timer_ctr_init_s     <= tmr_init_brnr_s;           --    VCU Timer = 90000 (OPL ID#38,51)
                  vcut_nxtst_s         <= VCUT_BRK_NORST;            
            ELSIF ((mc_no_pwr_i = '1')  AND                          -- MC = No Power (5% <= pwm_ctr <= 18.89%) AND
                    (((cab_act_i = '1') AND (ctmr_ctr_r = 0)) OR     -- Cab not active and cab timer elapsed OR
                      (vpb_valid_s(0) = '1'))) THEN                  -- ACK VPB is valid
                        init_tmr_s     <= '1';                       --    Reset timer for No Warning stage
                        timer_ctr_init_s  <= tmr_init_nowr_s;
                        vcut_nxtst_s   <= VCUT_NO_WARNING;
            END IF;

         WHEN OTHERS =>                                              -- Includes VCUT_IDLE State
            init_tmr_s                 <= '1';                       -- Reset VCU Timer
            init_ctmr_s                <= '1';                       -- Reset CAB Timer (4000)
            timer_ctr_init_s           <= tmr_init_nowr_s;           -- VCU Timer = no-warning state acc CCN03
            vcut_nxtst_s               <= VCUT_NO_WARNING;           -- REQ: 118. CCN03
            st_nosup_s                 <= '1';                       -- Avoid entering suppression mode
                                                                     -- (due to opmode_req rst values) before first
                                                                     -- 500us pulse
      END CASE;                                                      -- REQ END: 117

   END PROCESS p_vcut_fsm;

   ----------------------------------------------------------------------------
   --  OPMODE
   ----------------------------------------------------------------------------
   -- Register Opmode (needed for event handling)
   p_opmod: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         opmode_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN                                -- Hold mode transition until next 500us iteration
            opmode_r <= opmode_i;
         END IF;
      END IF;
   END PROCESS p_opmod;
   
   -- Inhibit transition to Test mode from other modes other than Suppression/Inactive mode (Req 57)  
   p_notst_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         st_notst_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         st_notst_r <= st_notst_s;
      END IF;
   END PROCESS p_notst_reg;   
   
   st_notst_s  <= '1' WHEN (opmode_r /= "00010") ELSE
                  '0';  

   -- Inhibit transition to Suppression mode (Req 52)
   p_nosup_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         st_nosup_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         st_nosup_r <= st_nosup_s;
      END IF;
   END PROCESS p_nosup_reg;

   -- Inhibit transition from Depressed to Normal Mode (Req 50)
   p_nonrm_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         st_nonrm_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         st_nonrm_r <= st_nonrm_s;
      END IF;
   END PROCESS p_nonrm_reg;


   -- Indicate Warning States
   p_vsu_wrn: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         st_1st_wrn_r <= '0';
         st_2st_wrn_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         st_1st_wrn_r <= st_1st_wrn_s;
         st_2st_wrn_r <= st_2st_wrn_s;
      END IF;
   END PROCESS p_vsu_wrn;

   -- Indicates that a speed limit exceeded ouput signal should be reported  
   --    (only when in Test mode and in Speed Limit Test state)
   p_vsu_spd_limit: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         spd_lim_exceed_tst_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         spd_lim_exceed_tst_r <= spd_lim_exceed_tst_s;
      END IF;
   END PROCESS p_vsu_spd_limit;

  ----------------------------------------------------------------------------
   --  VCU RST
   ----------------------------------------------------------------------------
   p_vcu_rst_ld_f: PROCESS(clk_i, arst_i)                         -- Indicator should actuate for 500ms.
   BEGIN
      IF (arst_i = '1') THEN
         vcu_rst_1_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500ms_i = '1') THEN
            vcu_rst_1_r <= vcu_rst_0_r;
         END IF;
      END IF;
   END PROCESS p_vcu_rst_ld_f;

   p_vcu_rst_f: PROCESS(clk_i, arst_i)                            -- Generate VCU RST 500ms pulse
   BEGIN
      IF (arst_i = '1') THEN
         vcu_rst_0_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (vcu_rst_1_s = '1') THEN
            vcu_rst_0_r <= '1';
         ELSIF (pulse500ms_i = '1') THEN
            vcu_rst_0_r <= '0';
         END IF;
      END IF;
   END PROCESS p_vcu_rst_f;
   vcu_rst_1_s <= vcu_rst_0_s WHEN (opmode_r /= "00010") ELSE     -- REQ: 137. De-asserted when in Supressed Mode
                   '0';

   edge_detector_i0 : edge_detector GENERIC MAP(G_EDGEPOLARITY => '1')
   PORT MAP(arst_i => arst_i, clk_i => clk_i, data_i => vsu_nowrn_s, edge_o => vcu_rst_0_s, valid_i => '1');

   ----------------------------------------------------------------------------
   --  VCU TIMER
   ----------------------------------------------------------------------------
   -- Timer
   p_timer: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         timer_ctr_r   <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            timer_ctr_r <= timer_ctr_s;
         END IF;
      END IF;
   END PROCESS p_timer;

   timer_ctr_s <= timer_ctr_init_s WHEN (init_tmr_s = '1') AND (vcu_tmr_hlt_i = '0') ELSE
                  timer_ctr_r - 1  WHEN (timer_ctr_r /= 0) AND (vcu_tmr_hlt_i = '0') ELSE
                  timer_ctr_r;

   -- Timer initializations
   WITH spd_i SELECT                                              -- REQ 112_117
      tmr_init_nowr_s  <= C_NOWR_LT3KMH   WHEN "00000001",
                          C_NOWR_HT3KMH   WHEN "00000011",
                          C_NOWR_HT23KMH  WHEN "00000111",
                          C_NOWR_HT25KMH  WHEN "00001111",
                          C_NOWR_HT75KMH  WHEN "00011111",
                          C_NOWR_HT90KMH  WHEN "00111111",
                          C_NOWR_HT110KMH WHEN "01111111",
                          C_NOWR_OVRSPD   WHEN OTHERS;

   tmr_init_1stw_s <= C_1STWRN_INIT;

   WITH spd_i SELECT                                              -- REQ 112_117
      tmr_init_2stw_s <= C_2STW_LT3KMH    WHEN "00000001",
                         C_2STW_HT3KMH    WHEN "00000011",
                         C_2STW_HT23KMH   WHEN "00000111",
                         C_2STW_HT25KMH   WHEN "00001111",
                         C_2STW_HT75KMH   WHEN "00011111",
                         C_2STW_HT90KMH   WHEN "00111111",
                         C_2STW_HT110KMH  WHEN "01111111",
                         C_2STW_OVRSPD    WHEN OTHERS;

   tmr_init_brnr_s   <= C_BRNR_INIT;

   tmr_init_dprs_s   <= C_DPRSD_INIT;

   tmr_init_nrml_s   <= C_NRML_INIT;

   tmr_init_trst_s   <= C_TSNR_INIT;

   ----------------------------------------------------------------------------
   --  CAB TIMER
   ----------------------------------------------------------------------------
   p_ctimer: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         ctmr_ctr_r   <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            ctmr_ctr_r <= ctmr_ctr_s;
         END IF;
      END IF;
   END PROCESS p_ctimer;
   ctmr_ctr_s <= C_CAB_INIT      WHEN (init_ctmr_s = '1') AND (vcu_tmr_hlt_i = '0') ELSE
                 ctmr_ctr_r - 1  WHEN (ctmr_ctr_r /= 0)   AND (vcu_tmr_hlt_i = '0') ELSE
                 ctmr_ctr_r;

   ----------------------------------------------------------------------------
   --  TEST MODE
   ----------------------------------------------------------------------------
   -- Detect State Change Request commanded by VPB
   p_st_chg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         tmod_st_inc_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (vigi_pb_i = '1') THEN
            tmod_st_inc_r <= '1';
         ELSIF (pulse500us_i = '1') THEN
            tmod_st_inc_r  <= '0';
         END IF;
      END IF;
   END PROCESS p_st_chg;

   -- Hold current state
   p_st_hld: PROCESS(clk_i, arst_i)                               -- REQ START: 61
   BEGIN
      IF (arst_i = '1') THEN
         vcut_st_hld_r <= VCUT_IDLE;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            vcut_st_hld_r <= vcut_st_hld_s;
         END IF;                                                     
      END IF;
   END PROCESS p_st_hld;                                                   
   
   -- [CCN05] deleted condition for inactive/suppressed mode
   --   from REQ 61 implies deleting previous "AND" condition
   --   here from previous code that was "AND Not in Suppressed Mode".
   vcut_st_hld_s  <= vcut_curst_r WHEN (opmode_r /= "01000") ELSE -- Do not update when in Test Mode.    
                     vcut_st_hld_r;                               -- (And keeps the state to return back to) 
                                                                  -- "_r" in curst: Give time to capture current
                                                                  -- state before state change. 
                                                                  -- REQ END: 61
   
   -- Detect exiting from test mode from last test state 
   p_tmod_xt: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         tmod_xt_re_s <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         tmod_xt_re_s <= tmod_end_s;
      END IF;
   END PROCESS p_tmod_xt;

   -- Detect entering test mode 
   tmod_init_s <= '1' WHEN (opmode_r = "00010") AND (opmode_i = "01000") ELSE    
                  '0';                                                          

   -- Detect exiting from test mode by deasserting test mode request 
   -- [CCN05] REQ 61  Upon assertion, will restore previous VCU state previously entering test mode, when 
   --   exiting said test mode.
   tmod_xt_s <= '1' WHEN (opmode_r = "01000") AND (opmode_i /= "01000") ELSE                           
                '0';                                                                                   

   -- Detect exiting from inactive/suppressed mode to active or ihibited/depressed mode
   -- [CCN05] REQ 115_56  Upon assertion, will reset timers and jump to VCU_NO_WARNING.
   supmod_xt_s <= '1' WHEN (opmode_r = "00010") AND ((opmode_i = "00001") or (opmode_i = "00100")) ELSE 
                  '0';
                  
   -- Detect exiting from ihibited/depressed mode to active mode
   -- [CCN05] Fixed small issue when exiting from VCUT_DEPRESSED state: FSM was going through an intermediate 
   --   state/mode when returning to Active mode and VCUT_BRK_NORST state.
   depmod_xt_s <= '1' WHEN (opmode_r = "00100") AND (opmode_i = "00001") ELSE                            
                  '0';                                                                                  

   ----------------------------------------------------------------------------
   --  TASK LINKED ACTIVITY MONITOR
   ----------------------------------------------------------------------------
   edge_detector_i1 : FOR i IN 0 TO tla_i'LEFT GENERATE
      edge_detector_i : edge_detector GENERIC MAP(G_EDGEPOLARITY => '1')
      PORT MAP(arst_i => arst_i, clk_i => clk_i, data_i => tla_i(i), edge_o => tla_re_s(i), valid_i => '1');
   END GENERATE edge_detector_i1;

   p_tla_evt: PROCESS(clk_i, arst_i)                              -- REQ: 122
      VARIABLE tla_evt_rem_v : T_EVT_REM := (OTHERS => (OTHERS => '0'));
   BEGIN
      IF (arst_i = '1') THEN
         tla_diff_0_r   <= (OTHERS => '0');
         tla_evt_ctr_r  <= C_TLA_CTR;
      ELSIF RISING_EDGE(clk_i) THEN
         FOR i IN 0 TO tla_i'LEFT LOOP

            FOR j IN 0 TO tla_i'LEFT LOOP                         -- Combinational OR of all other
               IF (i /= j) THEN                                   -- TLA edge detectors.
                  tla_evt_rem_v(i)(j) := tla_re_s(j);
               END IF;
            END LOOP;

            tla_diff_0_r(i) <= '0';
            IF ((tla_re_s(i) = '1')       AND
                (tla_evt_ctr_r(i) /= 0))  THEN
               tla_diff_0_r(i)   <= '1';
               IF (i /= 6) AND                                    -- [CCN05]: no decrement for Brake Demand 
                                                                  --    or Power Demand. REQ 214 
                  (i /= 0) THEN                                   --  No decrement for ss_bypass_pb_i
                  tla_evt_ctr_r(i) <= tla_evt_ctr_r(i) - 1;
               END IF;
            ELSIF ((OR_REDUCE(tla_evt_rem_v(i)) = '1')   OR       -- If any other TLA input is asserted
                   (vpb_valid_s(0) = '1')                OR       -- If an acknowledge input is asserted,
                                                                  --   (CCN03 change).                   
                   (opmode_r = "00010"))                 AND      -- VCU is suppressed
                   (opmode_r /= "01000")                 THEN     -- Do not reset TLA counter when in Test Mode
               tla_evt_ctr_r(i) <= C_TLA_CTR(i);                  -- Reset event counter
            END IF;

         END LOOP;
      END IF;
   END PROCESS p_tla_evt;

   p_tla_hld: PROCESS(clk_i, arst_i)                              -- Hold TLA events for 500us
   BEGIN
      IF (arst_i = '1') THEN
         tla_diff_1_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         FOR i IN 0 TO tla_i'LEFT LOOP
            IF (tla_diff_0_r(i) = '1') THEN
               tla_diff_1_r(i) <= '1';
            ELSIF (pulse500us_i = '1') THEN
               tla_diff_1_r(i)  <= '0';
            END IF;
        END LOOP;
      END IF;
   END PROCESS p_tla_hld;
   tla_diff_2_r <= OR_REDUCE(tla_diff_1_r);

   ----------------------------------------------------------------------------
   --  VPB HOLD MONITOR
   ----------------------------------------------------------------------------
   ack_s(0) <= vigi_pb_i;

   edge_detector_i2 : FOR i IN 0 TO ack_s'LEFT GENERATE
      edge_detector_i : edge_detector GENERIC MAP(G_EDGEPOLARITY => '1')
      PORT MAP(arst_i => arst_i, clk_i => clk_i, data_i => ack_s(i), edge_o => ack_re_s(i), valid_i => '1');
   END GENERATE edge_detector_i2;

   p_ack_evt: PROCESS(clk_i, arst_i)                              -- REQ: 112_117
   BEGIN
      IF (arst_i = '1') THEN
         ack_diff_0_r   <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         FOR i IN 0 TO ack_s'LEFT LOOP

            ack_diff_0_r(i) <= '0';
            IF ((ack_re_s(i) = '1')       AND
                (opmode_r /= "01000"))     THEN                   -- No ACK events when in Test Mode
               ack_diff_0_r(i)  <= '1';
            END IF;

         END LOOP;
      END IF;
   END PROCESS p_ack_evt;

   p_ack_hld: PROCESS(clk_i, arst_i)                              -- Hold ACK events for 500us
   BEGIN
      IF (arst_i = '1') THEN
         ack_diff_1_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         FOR i IN 0 TO ack_s'LEFT LOOP
            IF (ack_diff_0_r(i) = '1') THEN
               ack_diff_1_r(i) <= '1';
            ELSIF (pulse500us_i = '1') THEN
               ack_diff_1_r(i)  <= '0';
            END IF;
        END LOOP;
      END IF;
   END PROCESS p_ack_hld;
   vpb_valid_s(0) <= ack_diff_1_r(0);

   ----------------------------------------------------------------------------
   --  RADIO WARNING
   ----------------------------------------------------------------------------
   -- Radio Warning Timer (30s)
   p_radio_warning: PROCESS(clk_i, arst_i)                        -- REQ START: 63
   BEGIN                                                          -- REQ: 139_167_168
      IF (arst_i = '1') THEN
         radio_ctr_r  <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            radio_ctr_r <= radio_ctr_s;
         END IF;
      END IF;
   END PROCESS p_radio_warning;
   radio_ctr_s <= C_RDWR_INIT       WHEN (t6_tmr_en_mod_s = '1')  ELSE   -- Timer starts on next 500us pulse to stay
                  radio_ctr_r - 1   WHEN (radio_ctr_r /= 0)       AND    --  coherent with VCUT_NORMAL state timer.
                                         (vcu_tmr_hlt_i = '0')    ELSE
                  radio_ctr_r;

   t6_tmr_en_mod_s <= t6_tmr_en_s WHEN (opmode_r = "00100") OR    -- REQs: 62. CTR reset only allowed when in Depressed
                                       (opmode_r = "00001") ELSE  --  or Normal Mode.
                      '0';

   -- Radio Warning
   p_radio_out: PROCESS(clk_i, arst_i)                            -- REQ: 64
   BEGIN
      IF (arst_i = '1') THEN
         radio_r  <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         radio_r <= radio_1_s;
      END IF;
   END PROCESS p_radio_out;
   radio_1_s  <= '1' WHEN ((radio_ctr_r = 0)        AND
                                 (radio_0_s = '1')) AND
                                 (opmode_r /= "00010")     ELSE   -- REQ: 137. De-asserted when in Supressed Mode
                 '0';                                             -- REQ END: 63

   ----------------------------------------------------------------------------
   --  WARNING LIGHT
   ----------------------------------------------------------------------------
   -- Warning Light
   p_light_out: PROCESS(clk_i, arst_i)                            -- REQ START: 139_140_141
   BEGIN
      IF (arst_i = '1') THEN
         light_out_r      <= '0';
         light_stat_out_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            light_out_r      <= light_out_1_s;
            light_stat_out_r <= light_stat_out_s;
         END IF;
      END IF;
   END PROCESS p_light_out;
   light_out_1_s <= light_out_0_s WHEN (opmode_r /= "00010") ELSE -- REQ: 137. De-asserted when in Supressed Mode
                      '0';

   light_out_0_s <= fl_light_r   WHEN (flash_light_s = '1') ELSE
                   '1'           WHEN (solid_light_s = '1') ELSE
                   '0';

   light_stat_out_s <= '1' WHEN (((flash_light_s = '1') OR        -- REQ: 197
                                (solid_light_s = '1')) AND
                                (opmode_r /= "00010")) ELSE       --De-asserted when in Supressed Mode
                       '0';


   p_fl_light: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         fl_light_r  <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500ms_i = '1') THEN                             -- State updates at every 500ms
            fl_light_r <= fl_light_s;
         END IF;
      END IF;
   END PROCESS p_fl_light;
   fl_light_s <= NOT fl_light_r;                                  -- REQ END: 139_140_141

   ----------------------------------------------------------------------------
   --  BUZZER
   ----------------------------------------------------------------------------
   -- Buzzer
   p_buzzer_out: PROCESS(clk_i, arst_i)                           -- REQ START: 139_142_143
   BEGIN
      IF (arst_i = '1') THEN
         buzzer_r  <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse500us_i = '1') THEN
            buzzer_r <= buzzer_1_s;
         END IF;
      END IF;
   END PROCESS p_buzzer_out;
   buzzer_1_s <= '1' WHEN (buzzer_0_s = '1')   AND
                         (opmode_r /= "00010") ELSE               -- REQ: 137. De-asserted when in Supressed Mode
                '0';                                              -- REQ END: 139_142_143

   ----------------------------------------------------------------------------
   --  PENALTY BRAKES
   ----------------------------------------------------------------------------
   -- Penalty Brakes
   p_penalty_out: PROCESS(clk_i, arst_i)                          -- REQ: 139_163_164
   BEGIN
      IF (arst_i = '1') THEN
         penalty1_out_r <= '1';                                   -- Penalty Brakes are active-low
         penalty2_out_r <= '1';                                   -- Penalty Brakes are active-low
      ELSIF RISING_EDGE(clk_i) THEN
            penalty1_out_r <= penalty1_out_0_s;
            penalty2_out_r <= penalty2_out_0_s;
      END IF;
   END PROCESS p_penalty_out;
   penalty1_out_0_s <= '0' WHEN ((penalty1_out_s = '1')  AND
                                (opmode_r /= "00010")    AND      -- REQ 113_115_137: Depressed and Supressed mode:
                                (opmode_r /= "00100"))   OR       -- No penalty brake or park brake output
                                (opmode_r = "10000")     ELSE     -- REQ: 104. Major fault issues penalty brake
                      '1';                                        --  application
   penalty2_out_0_s <= '0' WHEN ((penalty2_out_s = '1')  AND
                                (opmode_r /= "00010")    AND      -- REQ 113_115_137: Depressed and Supressed mode:
                                (opmode_r /= "00100"))   OR       -- No penalty brake or park brake output
                               (opmode_r = "10000")      ELSE     -- REQ: 104. Major fault issues penalty brake
                      '1';                                        --  application

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   vis_warn_stat_o     <= light_stat_out_r;                       -- Visible Warning Status
   light_out_o         <= light_out_r;                            -- Flashing Light (1st/2nd Stage Warning) 
                                                                  --     and in Test Mode (VCUT_SPD_LIMIT_TEST)
   buzzer_o            <= buzzer_r;                               -- Buzzer Output (2nd Stage Warning)
   penalty1_out_o      <= penalty1_out_r;                         -- Penalty Brake 1
   penalty2_out_o      <= penalty2_out_r;                         -- Penalty Brake 2
   rly_out1_3V_o       <= radio_r;                                -- Radio Warning

   st_notst_o          <= st_notst_r;
   st_nosup_o          <= st_nosup_r;                             -- Inhibit transition to Suppression Mode
   st_nonrm_o          <= st_nonrm_r;                             -- Inhibit transition from Depressed to Normal Mode 
                                                                  --    
   tmod_xt_o           <= tmod_xt_re_s;                           -- Test Mode Exit
   vcu_rst_o           <= vcu_rst_1_r;                            -- For TMS

   st_1st_wrn_o        <= st_1st_wrn_r;                           -- Indicate VCU in 1st Warning (for Diag)
   st_2st_wrn_o        <= st_2st_wrn_r;                           -- Indicate VCU in 2st Warning (for Diag)
   spd_lim_exceed_tst_o<= spd_lim_exceed_tst_r;                   -- Indicate VCU in Speed Limit state (Test) 
                                                                  --   (to be used to force output signals 
                                                                  --    Speed Limit Excedded #1/#2 )
   opmode_o            <= opmode_r;

END ARCHITECTURE beh;
