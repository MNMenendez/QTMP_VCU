---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : vcu_timing_system.vhd
-- Module      : VCU Timing System
-- Revision    : 1.8
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Top-Level of the VCU Timing System HLB
---------------------------------------------------------------
-- History :
-- Revision 1.8 - May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.7 - April 14, 2021
--    - NRibeiro: [CCN05] Fixed comments: ±12.5% was changed to 5%
-- Revision 1.6 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.5 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes.
-- Revision 1.4 - April 11, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.3 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.2 - March 05, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 15, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY vcu_timing_system IS
   PORT (

      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;      -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;      -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i         : IN STD_LOGIC;      -- Internal 500ms synch pulse
      pulse500us_i         : IN STD_LOGIC;      -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  Mode Selector Inputs
      ----------------------------------------------------------------------------
      bcp_75_i             : IN STD_LOGIC;      -- Brake Cylinder Pressure above 75% (external input)
      cab_act_i            : IN STD_LOGIC;      -- Cab Active (external input)
      hcs_mode_i           : IN STD_LOGIC;      -- Communication-based train control (sets VCU in depressed mode)      
      zero_spd_i           : IN STD_LOGIC;      -- Zero Speed (external input)
      driverless_i         : IN STD_LOGIC;      -- Driverless (external input)

      ----------------------------------------------------------------------------
      --  TLA Inputs
      ----------------------------------------------------------------------------
      horn_low_i           : IN STD_LOGIC;      -- Horn Low
      horn_high_i          : IN STD_LOGIC;      -- Horn High
      horn_low_raw_i       : IN STD_LOGIC;      -- Horn Low raw
      horn_high_raw_i      : IN STD_LOGIC;      -- Horn High raw
      hl_low_i             : IN STD_LOGIC;      -- Headlight Low
      w_wiper_pb_i         : IN STD_LOGIC;      -- Washer Wiper Push Button
      ss_bypass_pb_i       : IN STD_LOGIC;      -- Safety system bypass Push Button

      ----------------------------------------------------------------------------
      --  Acknowledge Inputs
      ----------------------------------------------------------------------------
      vigi_pb_raw_i        : IN STD_LOGIC;      -- Vigilance Push Button raw. CCN03
      vigi_pb_i            : IN STD_LOGIC;      -- Vigilance Push Button
      vigi_pb_hld_i        : IN STD_LOGIC;      -- Vigilance Push Button Held (internal)

      ----------------------------------------------------------------------------
      --  PWM Processed Inputs
      ----------------------------------------------------------------------------
      pwr_brk_dmnd_i       : IN STD_LOGIC;      -- Movement of MC changing ±5% the braking demand or 
                                                --                      ±5% the power demand (req 38 and req 39)
      mc_no_pwr_i          : IN STD_LOGIC;      -- MC = No Power

      ----------------------------------------------------------------------------
      --  Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_l3kmh_i          : IN STD_LOGIC;      -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i          : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i         : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i        : IN STD_LOGIC;      -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i       : IN STD_LOGIC;      -- 4-20mA Speed Indicating Speed Overrange

      ----------------------------------------------------------------------------
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i            : IN STD_LOGIC;      -- Major Fault
      spd_err_i            : IN STD_LOGIC;      -- Analog Speed Error (OPL ID#40)
      zero_spd_flt_i       : IN STD_LOGIC;      -- Digital zero speed fault, processed from external input

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      vis_warn_stat_o      : OUT STD_LOGIC;     -- Visible Warning Status                      CCN03
      light_out_o          : OUT STD_LOGIC;     -- Flashing Light (1st Stage Warning)
      buzzer_o             : OUT STD_LOGIC;     -- Buzzer Output (2nd Stage Warning)
      penalty1_out_o       : OUT STD_LOGIC;     -- Penalty Brake 1
      penalty2_out_o       : OUT STD_LOGIC;     -- Penalty Brake 2
      rly_out1_3V_o        : OUT STD_LOGIC;     -- Radio Warning
      vcu_rst_o            : OUT STD_LOGIC;     -- VCU RST (for TMS)

      st_1st_wrn_o         : OUT STD_LOGIC;     -- Notify VCU 1st Warning
      st_2st_wrn_o         : OUT STD_LOGIC;     -- Notify VCU 2st Warning
      zero_spd_o           : OUT STD_LOGIC;     -- Notify Zero Speed Calc
      spd_lim_exceed_tst_o  : OUT STD_LOGIC;    -- Notify VCU Speed Limit state (Test)

      opmode_mft_o         : OUT STD_LOGIC;     -- Notify Major Fault opmode
      opmode_tst_o         : OUT STD_LOGIC;     -- Notify Test opmode
      opmode_dep_o         : OUT STD_LOGIC;     -- Notify Depression opmode
      opmode_sup_o         : OUT STD_LOGIC;     -- Notify Suppression opmode
      opmode_nrm_o         : OUT STD_LOGIC      -- Notify Normal opmode

   );
END ENTITY vcu_timing_system;


ARCHITECTURE str OF vcu_timing_system IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------
   -- Operation Mode Request
   COMPONENT opmode_req IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;                     -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;                     -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i         : IN STD_LOGIC;                     -- Internal 500us synch pulse
      ----------------------------------------------------------------------------
      --  Raw Inputs
      ----------------------------------------------------------------------------
      bcp_75_i             : IN STD_LOGIC;                     -- Brake Cylinder Pressure above 75% (external input)
      cab_act_i            : IN STD_LOGIC;                     -- Cab Active (external input)
      cbtc_i               : IN STD_LOGIC;                     -- Communication-based train control
      digi_zero_spd_i      : IN STD_LOGIC;                     -- Zero Speed (external input)
      driverless_i         : IN STD_LOGIC;                     -- Driverless (external input)
      anlg_spd_i           : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Aggregated speed signals
      vigi_pb_i            : IN STD_LOGIC;                     -- Vigilance Push Button
      tmod_xt_i            : IN STD_LOGIC;                     -- Exit test mode

      ----------------------------------------------------------------------------
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      anlg_spd_err_i       : IN STD_LOGIC;                     -- Analog Speed Error (OPL ID#40)
      digi_zero_spd_flt_i  : IN STD_LOGIC;                     -- Digital zero speed flt, processed from external input

      ----------------------------------------------------------------------------
      --  Notification Outputs
      ----------------------------------------------------------------------------
      zero_spd_o           : OUT STD_LOGIC;                    -- Calculated Zero Speed

      ----------------------------------------------------------------------------
      --  Mode Request Outputs
      ----------------------------------------------------------------------------
      sup_req_o            : OUT STD_LOGIC;                    -- Suppression Request
      dep_req_o            : OUT STD_LOGIC;                    -- Depression Request
      tst_req_o            : OUT STD_LOGIC                     -- Test Mode Request

   );
   END COMPONENT opmode_req;

   -- Operation Mode FSM
   COMPONENT opmode_fsm IS
      PORT
      (
         ----------------------------------------------------------------------------
         --  Clock/Reset Inputs
         ----------------------------------------------------------------------------
         arst_i            : IN STD_LOGIC;                     -- Global (asynch) reset
         clk_i             : IN STD_LOGIC;                     -- Global clk

         ----------------------------------------------------------------------------
         --  Mode Request Inputs
         ----------------------------------------------------------------------------
         mjr_flt_i         : IN STD_LOGIC;                     -- Major Fault
         tst_req_i         : IN STD_LOGIC;                     -- Test Mode Request
         dep_req_i         : IN STD_LOGIC;                     -- Depression Request
         sup_req_i         : IN STD_LOGIC;                     -- Suppression Request

         st_notst_i        : IN STD_LOGIC;                     -- Inhibit transition to Test Mode
         st_nosup_i        : IN STD_LOGIC;                     -- Inhibit transition to Suppression Mode
         st_nonrm_i        : IN STD_LOGIC;                     -- Inhibit transition from Depressed to Normal Mode

         tmod_xt_i         : IN STD_LOGIC;                     -- VCU FSM Test Mode Exit

         ----------------------------------------------------------------------------
         --  Current Operation Mode Output
         ----------------------------------------------------------------------------
         opmode_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0); -- Current Operation Mode
         vcu_tmr_hlt_o     : OUT STD_LOGIC                     -- Halt VCU FSM

      );
   END COMPONENT opmode_fsm;

   -- VCU Timing FSM
   COMPONENT vcu_timing_fsm IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;                     -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;                     -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500ms_i         : IN STD_LOGIC;                     -- Internal 500ms synch pulse
      pulse500us_i         : IN STD_LOGIC;                     -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  Decision Inputs
      ----------------------------------------------------------------------------
      tla_i                : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Aggregated Task Linked Activity
      spd_i                : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Aggregated speed signals
      opmode_i             : IN STD_LOGIC_VECTOR(4 DOWNTO 0);  -- Current Operation Mode

      vigi_pb_i            : IN STD_LOGIC;                     -- Vigilance Push Button
      vigi_pb_hld_i        : IN STD_LOGIC;                     -- Vigilance Push Button Held (internal)

      zero_spd_i           : IN STD_LOGIC;                     -- Zero Speed Input
      spd_err_i            : IN STD_LOGIC;                     -- Analog Speed Error (under/over range) internal signal
      cab_act_i            : IN STD_LOGIC;                     -- Cab Ative
      mc_no_pwr_i          : IN STD_LOGIC;                     -- MC = No Power

      vcu_tmr_hlt_i        : IN STD_LOGIC;                     -- Halt VCU FSM

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      vis_warn_stat_o      : OUT STD_LOGIC;                    -- Visible Warning Status
      light_out_o          : OUT STD_LOGIC;                    -- Flashing Light
      buzzer_o             : OUT STD_LOGIC;                    -- Buzzer
      penalty1_out_o       : OUT STD_LOGIC;                    -- Penalty Brake 1
      penalty2_out_o       : OUT STD_LOGIC;                    -- Penalty Brake 2
      rly_out1_3V_o        : OUT STD_LOGIC;                    -- Radio Warning Relay

      st_notst_o           : OUT STD_LOGIC;                    -- Inhibit transition to Test Mode
      st_nosup_o           : OUT STD_LOGIC;                    -- Inhibit transition to Suppression Mode
      st_nonrm_o           : OUT STD_LOGIC;                    -- Inhibit transition from Depressed to Normal Mode
      st_1st_wrn_o         : OUT STD_LOGIC;                    -- Indicate VCU in 1st Warning (for Diag)
      st_2st_wrn_o         : OUT STD_LOGIC;                    -- Indicate VCU in 2st Warning (for Diag)
      vcu_rst_o            : OUT STD_LOGIC;                    -- VCU RST (for TMS)

      tmod_xt_o            : OUT STD_LOGIC;                    -- Test Mode Exit
      opmode_o             : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      spd_lim_exceed_tst_o  : OUT STD_LOGIC

   );
   END COMPONENT vcu_timing_fsm;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Input vectors
   SIGNAL tla_s            : STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL spd_s            : STD_LOGIC_VECTOR(7 DOWNTO 0);

   -- Operation Mode Request
   SIGNAL sup_req_s        : STD_LOGIC;
   SIGNAL dep_req_s        : STD_LOGIC;
   SIGNAL tst_req_s        : STD_LOGIC;

   -- Operation Mode FSM
   SIGNAL vcu_tmr_hlt_s    : STD_LOGIC;

   -- VCU Timing FSM
   SIGNAL opmode_precal_s  : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL opmode_s         : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL st_notst_s       : STD_LOGIC;
   SIGNAL st_nosup_s       : STD_LOGIC;
   SIGNAL st_nonrm_s       : STD_LOGIC;
   SIGNAL st_1st_wrn_s     : STD_LOGIC;
   SIGNAL st_2st_wrn_s     : STD_LOGIC;
   SIGNAL tmod_xt_s        : STD_LOGIC;
   SIGNAL vcu_rst_s        : STD_LOGIC;
   SIGNAL spd_lim_exceed_tst_s : STD_LOGIC;

   -- TLA mask
   SIGNAL tla_mask_s       : STD_LOGIC;
   SIGNAL vpb_mask_s       : STD_LOGIC;
   SIGNAL horn_low_mask_s  : STD_LOGIC;
   SIGNAL horn_high_mask_s : STD_LOGIC;

   SIGNAL vigi_pb_s        : STD_LOGIC;
   SIGNAL pwr_brk_dmnd_s   : STD_LOGIC;
   SIGNAL horn_low_s       : STD_LOGIC;
   SIGNAL horn_high_s      : STD_LOGIC;
   SIGNAL hl_low_s         : STD_LOGIC;
   SIGNAL w_wiper_pb_s     : STD_LOGIC;
   SIGNAL ss_bypass_pb_s   : STD_LOGIC;

   -- Operation
   SIGNAL zero_spd_s       : STD_LOGIC;

   -- Outputs
   SIGNAL vis_warn_stat_s  : STD_LOGIC;
   SIGNAL light_out_s      : STD_LOGIC;
   SIGNAL buzzer_s         : STD_LOGIC;
   SIGNAL penalty1_out_s   : STD_LOGIC;
   SIGNAL penalty2_out_s   : STD_LOGIC;
   SIGNAL rly_out1_3V_s    : STD_LOGIC;

BEGIN

   -- Operation Mode Request
   opmode_req_i0: opmode_req
   PORT MAP
   (
      arst_i               => arst_i,
      clk_i                => clk_i,

      pulse500us_i         => pulse500us_i,

      bcp_75_i             => bcp_75_i,
      cab_act_i            => cab_act_i,
      cbtc_i               => hcs_mode_i,
      anlg_spd_i           => spd_s,
      digi_zero_spd_i      => zero_spd_i,
      driverless_i         => driverless_i,

      anlg_spd_err_i       => spd_err_i,
      digi_zero_spd_flt_i  => zero_spd_flt_i,
      vigi_pb_i            => vigi_pb_raw_i,
      zero_spd_o           => zero_spd_s,

      sup_req_o            => sup_req_s,
      dep_req_o            => dep_req_s,
      tst_req_o            => tst_req_s,
      tmod_xt_i            => tmod_xt_s

);

   -- Operation Mode FSM
   opmode_fsm_i0: opmode_fsm
   PORT MAP
   (
      arst_i               => arst_i,
      clk_i                => clk_i,

      mjr_flt_i            => mjr_flt_i,
      tst_req_i            => tst_req_s,
      dep_req_i            => dep_req_s,
      sup_req_i            => sup_req_s,

      st_notst_i           => st_notst_s,
      st_nosup_i           => st_nosup_s,
      st_nonrm_i           => st_nonrm_s,

      tmod_xt_i            => tmod_xt_s,

      opmode_o             => opmode_precal_s,
      vcu_tmr_hlt_o        => vcu_tmr_hlt_s

   );

   -- VCU Timing FSM
   vcu_timing_fsm_i0 : vcu_timing_fsm
   PORT MAP
   (
      arst_i               => arst_i,
      clk_i                => clk_i,

      pulse500ms_i         => pulse500ms_i,
      pulse500us_i         => pulse500us_i,

      tla_i                => tla_s,
      spd_i                => spd_s,
      opmode_i             => opmode_precal_s,

      vigi_pb_i            => vigi_pb_s,
      vigi_pb_hld_i        => vigi_pb_hld_i,

      zero_spd_i           => zero_spd_i,
      spd_err_i            => spd_err_i,
      cab_act_i            => cab_act_i,
      mc_no_pwr_i          => mc_no_pwr_i,

      vcu_tmr_hlt_i        => vcu_tmr_hlt_s,

      light_out_o          => light_out_s,
      vis_warn_stat_o      => vis_warn_stat_s,
      buzzer_o             => buzzer_s,
      penalty1_out_o       => penalty1_out_s,
      penalty2_out_o       => penalty2_out_s,
      rly_out1_3V_o        => rly_out1_3V_s,

      st_notst_o           => st_notst_s,
      st_nosup_o           => st_nosup_s,
      st_nonrm_o           => st_nonrm_s,
      st_1st_wrn_o         => st_1st_wrn_s,
      st_2st_wrn_o         => st_2st_wrn_s,
      vcu_rst_o            => vcu_rst_s,

      tmod_xt_o            => tmod_xt_s,
      opmode_o             => opmode_s,
      spd_lim_exceed_tst_o => spd_lim_exceed_tst_s
   );


   --------------------------------------------------------
   -- TLA MASK
   --------------------------------------------------------
   --REQ START: 204                                                             -- NR (2019/11/5)
   tla_mask_s       <= vigi_pb_raw_i OR horn_low_raw_i OR horn_high_raw_i;      -- deleted oep_ack_raw_i from equation
   vpb_mask_s       <= horn_low_raw_i OR horn_high_raw_i;                       -- deleted oep_ack_raw_i from equation
   horn_low_mask_s  <= vigi_pb_raw_i OR horn_high_raw_i;                        -- deleted oep_ack_raw_i from equation
   horn_high_mask_s <= vigi_pb_raw_i OR horn_low_raw_i;                         -- deleted oep_ack_raw_i from equation

   vigi_pb_s        <= vigi_pb_i AND NOT vpb_mask_s;
   pwr_brk_dmnd_s   <= pwr_brk_dmnd_i AND NOT tla_mask_s;
   horn_low_s       <= horn_low_i AND NOT horn_low_mask_s;
   horn_high_s      <= horn_high_i AND NOT horn_high_mask_s;
   hl_low_s         <= hl_low_i AND NOT tla_mask_s;
   w_wiper_pb_s     <= w_wiper_pb_i AND NOT tla_mask_s;
   ss_bypass_pb_s   <= ss_bypass_pb_i AND NOT tla_mask_s;

   --REQ END;

   --------------------------------------------------------
   -- INPUT AGGREGATE
   --------------------------------------------------------
   spd_s <= spd_over_spd_i &
            spd_h110kmh_i  &
            spd_h90kmh_i   &
            spd_h75kmh_i   &
            spd_h25kmh_i   &
            spd_h23kmh_i   &
            spd_h3kmh_i    &
            spd_l3kmh_i;
                                                            -- REQ: 112_117_121_204
   tla_s <= '0'                              &              -- NR CCN04 removed the brk_dmnd_s exclusived contribuition
            (pwr_brk_dmnd_s AND opmode_s(0)) &              -- MC Movement: Brake or Power Demand. Used in normal mode
            horn_low_s                       &              -- Horn Low or Horn High operation
            horn_high_s                      &
            hl_low_s                         &              -- Headlight operation
            w_wiper_pb_s                     &              -- Wiper/washer operation
            '0'                              &              -- NR CCN04 Removed (PTT Radio foot switch)
            ss_bypass_pb_s;                                 -- Safety system bypass ack button

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   light_out_o          <= light_out_s;
   vis_warn_stat_o      <= vis_warn_stat_s;                 -- REQ: 197
   buzzer_o             <= buzzer_s;
   penalty1_out_o       <= penalty1_out_s;
   penalty2_out_o       <= penalty2_out_s;
   rly_out1_3V_o        <= rly_out1_3V_s;
   vcu_rst_o            <= vcu_rst_s;
   st_1st_wrn_o         <= st_1st_wrn_s;                    -- Notify VCU 1st Warning
   st_2st_wrn_o         <= st_2st_wrn_s;                    -- Notify VCU 2st Warning
   zero_spd_o           <= zero_spd_s;                      -- Notify Zero Speed Calc
   spd_lim_exceed_tst_o <= spd_lim_exceed_tst_s;            -- Notify (and force) Speed Limit state 
                                                            --                (from test mode state)
   opmode_mft_o         <= opmode_s(4);                     -- Notify Major Fault opmode
   opmode_tst_o         <= opmode_s(3);                     -- Notify Test opmode
   opmode_dep_o         <= opmode_s(2);                     -- REQ: 137.
   opmode_sup_o         <= opmode_s(1);                     -- REQ: 137.
   opmode_nrm_o         <= opmode_s(0);                     -- REQ: 137.

END ARCHITECTURE str;