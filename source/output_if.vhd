---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : output_if.vhd
-- Module      : Output IF
-- Revision    : 1.8
-- Date/Time   : December 11, 2019
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Output IF
---------------------------------------------------------------
-- History :
-- Revision 1.8 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.7 - November 29, 2019
--    - NRibeiro: Applied code changes for CCN04.
-- Revision 1.6 - April 01, 2019
--    - AFernandes: Applied code changes for CCN03.
-- Revision 1.5 - July 27, 2018
--    - AFernandes: Applied code changes for CCN02 02.
-- Revision 1.4 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.3 - March 05, 2018
--    - JMonteiro: Applied code review comments.
--                 Added status LED output drive logic
-- Revision 1.2 - February 27, 2018
--    - JMonteiro: Replaced hardcoded range wet_s'LEFT
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - February 02, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY output_if IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i                  : IN STD_LOGIC;   -- Global (asynch) reset
      clk_i                   : IN STD_LOGIC;   -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i            : IN STD_LOGIC;   -- Internal 500us synch pulse
      pulse250ms_i            : IN STD_LOGIC;   -- Internal 250ms synch pulse

      ----------------------------------------------------------------------------
      --  Digital (Wet) Outputs
      ----------------------------------------------------------------------------
      light_out_i             : IN STD_LOGIC;   -- Warning Light

      tms_pb_i                : IN STD_LOGIC;   -- TMS Vigilance Push Button
      tms_spd_lim_overridden_i: IN STD_LOGIC;   -- TMS Speed Limit Override
      tms_rst_i               : IN STD_LOGIC;   -- TMS Vigilance Reset
      tms_penalty_stat_i      : IN STD_LOGIC;   -- TMS Penalty Brake Status
      tms_major_fault_i       : IN STD_LOGIC;   -- TMS Vigilance Major Fault
      tms_minor_fault_i       : IN STD_LOGIC;   -- TMS Vigilance Minor Fault
      tms_depressed_i         : IN STD_LOGIC;   -- TMS Vigilance Depressed Mode
      tms_suppressed_i        : IN STD_LOGIC;   -- TMS Vigilance Suppressed Mode
      tms_vis_warn_stat_i     : IN STD_LOGIC;   -- TMS Visible Warning Status
      tms_spd_lim_stat_i      : IN STD_LOGIC;   -- TMS Speed Limit Timer Status

      buzzer_out_i            : IN STD_LOGIC;   -- Warning Buzzer

      ----------------------------------------------------------------------------
      --  Digital (Wet) Output Feedback In
      ----------------------------------------------------------------------------
      light_out_fb_i          : IN STD_LOGIC;   -- Warning Light Signal Feedback

      tms_pb_fb_i             : IN STD_LOGIC;   -- TMS Vigilance Push Button Signal Feedback
      tms_spd_lim_overridden_fb_i: IN STD_LOGIC;-- TMS Speed Limit Overridden Signal Feedback
      tms_rst_fb_i            : IN STD_LOGIC;   -- TMS Vigilance Reset Signal Feedback
      tms_penalty_stat_fb_i   : IN STD_LOGIC;   -- TMS Penalty Brake Status Signal Feedback
      tms_major_fault_fb_i    : IN STD_LOGIC;   -- TMS Vigilance Major Fault Signal Feedback
      tms_minor_fault_fb_i    : IN STD_LOGIC;   -- TMS Vigilance Minor Fault Signal Feedback
      tms_depressed_fb_i      : IN STD_LOGIC;   -- TMS Vigilance Depressed Mode Signal Feedback
      tms_suppressed_fb_i     : IN STD_LOGIC;   -- TMS Vigilance Suppressed Mode Signal Feedback
      tms_vis_warn_stat_fb_i  : IN STD_LOGIC;   -- TMS Visible Warning Status Output Feedback
      tms_spd_lim_stat_fb_i   : IN STD_LOGIC;   -- TMS Speed Limit Timer Status Signal Feedback

      buzzer_out_fb_i         : IN STD_LOGIC;   -- Warning Buzzer Signal Feedback

      ----------------------------------------------------------------------------
      --  Relay (Dry) Outputs
      ----------------------------------------------------------------------------
      penalty1_out_i          : IN STD_LOGIC;   -- Penalty Brake Channel #1 Output
      penalty2_out_i          : IN STD_LOGIC;   -- Penalty Brake Channel #2 Output

      rly_out3_3V_i           : IN STD_LOGIC;   -- Speed Limit Exceeded 2
      rly_out2_3V_i           : IN STD_LOGIC;   -- Speed Limit Exceeded 1
      rly_out1_3V_i           : IN STD_LOGIC;   -- Radio Warning Relay

      ----------------------------------------------------------------------------
      --  Relay (Dry) Output Feedback In
      ----------------------------------------------------------------------------
      penalty2_fb_i           : IN STD_LOGIC;   -- Penalty Brake Channel #2 Signal Feedback Input
      penalty1_fb_i           : IN STD_LOGIC;   -- Penalty Brake Channel #1 Signal Feedback Input

      rly_fb3_3V_i            : IN STD_LOGIC;   -- Relay 3 Feedback
      rly_fb2_3V_i            : IN STD_LOGIC;   -- Relay 2 Feedback
      rly_fb1_3V_i            : IN STD_LOGIC;   -- Relay 1 Feedback

      ----------------------------------------------------------------------------
      --  Digital (Wet) Outputs
      ----------------------------------------------------------------------------
      wet_o                   : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
      wet_flt_o               : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);

      ----------------------------------------------------------------------------
      --  Relay (Dry) Outputs
      ----------------------------------------------------------------------------
      dry_o                   : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
      dry_flt_o               : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);

      ----------------------------------------------------------------------------
      --  Status LED output
      ----------------------------------------------------------------------------
      status_led_o            : OUT STD_LOGIC

   );
END ENTITY output_if;


ARCHITECTURE beh OF output_if IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------

   -- Signal Compare
   COMPONENT sig_comp IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i         : IN STD_LOGIC;      -- Global (asynch) reset
      clk_i          : IN STD_LOGIC;      -- Global clk

      ----------------------------------------------------------------------------
      --  Timing
      ----------------------------------------------------------------------------
      pulse500us_i      : IN STD_LOGIC;   -- Internal 500us synch pulse

      ----------------------------------------------------------------------------
      --  Control
      ----------------------------------------------------------------------------
      cmp_init_i     : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Input (signals to be compared)
      ----------------------------------------------------------------------------
      cmp_sig1_i     : IN STD_LOGIC;
      cmp_sig2_i     : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Output (compare result)
      ----------------------------------------------------------------------------
      cmp_res_o      : OUT STD_LOGIC

   );
   END COMPONENT sig_comp;


   COMPONENT error_counter_filter IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- valid input
      valid_i              : IN  STD_LOGIC;
      -- error input
      fault_i              : IN  STD_LOGIC;
      -- Permanent fault output
      fault_o              : OUT STD_LOGIC
   );
   END COMPONENT error_counter_filter;

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Input aggregate
   SIGNAL wet_s      : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL wet_r      : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL wet_fb_s   : STD_LOGIC_VECTOR(11 DOWNTO 0);

   SIGNAL dry_s      : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL dry_r      : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL dry_fb_s   : STD_LOGIC_VECTOR(4 DOWNTO 0);

   -- Event detect
   SIGNAL wet_diff_s : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL dry_diff_s : STD_LOGIC_VECTOR( 4 DOWNTO 0);

   -- Compare result
   SIGNAL wet_cmp_s0  : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL wet_cmp_s1  : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL dry_cmp_s   : STD_LOGIC_VECTOR( 4 DOWNTO 0);

   -- Output Mask
   SIGNAL dry_msk_s  : STD_LOGIC_VECTOR( 4 DOWNTO 0);
   SIGNAL dry_msk_r  : STD_LOGIC_VECTOR( 4 DOWNTO 0);

   -- Masked outputs
   SIGNAL wet_out_r  : STD_LOGIC_VECTOR(11 DOWNTO 0);

   -- Fault Gen
   SIGNAL wet_flt_s  : STD_LOGIC_VECTOR(11 DOWNTO 0);
   SIGNAL wet_flt_r  : STD_LOGIC_VECTOR(11 DOWNTO 0);

   SIGNAL dry_flt_s  : STD_LOGIC_VECTOR( 4 DOWNTO 0);
   SIGNAL dry_flt_r  : STD_LOGIC_VECTOR( 4 DOWNTO 0);

   -- Status LED
   SIGNAL status_led_r : STD_LOGIC;

BEGIN

   --------------------------------------------------------
   -- DIGITAL (WET) OUTPUT EVAL
   --------------------------------------------------------
   sig_comp_i0: FOR i IN 0 TO wet_s'LEFT GENERATE                                    -- REQ: 65
      sig_comp_i: sig_comp
      PORT MAP
      (
         arst_i         => arst_i,
         clk_i          => clk_i,

         pulse500us_i   => pulse500us_i,

         cmp_init_i     => wet_diff_s(i),

         cmp_sig1_i     => wet_s(i),
         cmp_sig2_i     => wet_fb_s(i),

         cmp_res_o      => wet_cmp_s0(i)
      );
   END GENERATE;

   p_wet_diff: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         wet_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         wet_r <= wet_s;
      END IF;
   END PROCESS p_wet_diff;
   wet_diff_s <= wet_s XOR wet_r;

   --------------------------------------------------------
   -- RELAY (DRY) OUTPUT EVAL
   --------------------------------------------------------
   sig_comp_i1: FOR i IN 0 TO dry_s'LEFT GENERATE                                   -- REQ: 65

      sig_comp_i: sig_comp
      PORT MAP
      (
         arst_i         => arst_i,
         clk_i          => clk_i,

         pulse500us_i   => pulse500us_i,

         cmp_init_i     => dry_diff_s(i),

         cmp_sig1_i     => dry_s(i),
         cmp_sig2_i     => dry_fb_s(i),

         cmp_res_o      => dry_cmp_s(i)
      );
   END GENERATE;

   p_dry_diff: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         dry_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         dry_r <= dry_s;
      END IF;
   END PROCESS p_dry_diff;
   dry_diff_s <= dry_s XOR dry_r;

   --------------------------------------------------------
   -- DIGITAL (WET) OUTPUT MASK
   --------------------------------------------------------
   p_wet_out: PROCESS(clk_i, arst_i)                              -- Initialize compare logic
   BEGIN                                                          -- uppon output assertion
      IF (arst_i = '1') THEN
         wet_out_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         wet_out_r    <= wet_s AND NOT(wet_flt_r);                -- Wet outputs masked as per REQ 66
         --wet_out_r(6) <= wet_s(6) OR wet_flt_r(6);              -- Penalty Brake asserted low. CCN03 Change. Inverted in TMS
      END IF;
   END PROCESS p_wet_out;


   error_counter_filter_i0: For i IN 0 TO wet_s'LEFT GENERATE                       --REQ: 66

      wet_cmp_s1(i) <= NOT wet_cmp_s0(i);

      error_counter_filter_i: error_counter_filter
         PORT MAP (
            arst_i      => arst_i,
            clk_i       => clk_i,
            valid_i     => pulse250ms_i,
            fault_i     => wet_cmp_s1(i),
            fault_o     => wet_flt_s(i)
      );
   END GENERATE;

   p_wet_flt: PROCESS(clk_i, arst_i)                                                -- Persistent fault
   BEGIN
      IF (arst_i = '1') THEN
         wet_flt_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         FOR i IN 0 TO (wet_flt_s'LENGTH-1) LOOP
            IF (wet_flt_s(i) = '1') THEN
               wet_flt_r(i) <= '1';
            END IF;
         END LOOP;
      END IF;
   END PROCESS p_wet_flt;

   --------------------------------------------------------
   -- RELAY (DRY) OUTPUT MASK
   --------------------------------------------------------
   p_dry_msk: PROCESS(clk_i, arst_i)                                                -- REQ START: 67
   BEGIN                                                                            -- Initialize compare logic uppon output assertion
      IF (arst_i = '1') THEN
         dry_msk_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         dry_msk_r <= dry_msk_s;
      END IF;
   END PROCESS p_dry_msk;
   dry_msk_s   <= dry_s;                                                            -- Dry outputs are not masket as per REQ 67.

   p_dry_flt: PROCESS(clk_i, arst_i)                                                -- Persistent fault
   BEGIN
      IF (arst_i = '1') THEN
         dry_flt_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         FOR i IN 0 TO (dry_flt_s'LENGTH-1) LOOP
            IF (dry_flt_s(i) = '1') THEN
               dry_flt_r(i) <= '1';
            END IF;
         END LOOP;
      END IF;
   END PROCESS p_dry_flt;
   dry_flt_s   <= NOT dry_cmp_s;                                                    -- REQ END: 67

   --------------------------------------------------------
   -- STATUS LED
   --------------------------------------------------------
   -- Status LED out  TEST ONLY
   p_status_led: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i = '1') THEN
         status_led_r <= '1';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (pulse250ms_i = '1') THEN
            status_led_r <= NOT status_led_r;
         END IF;
      END IF;
   END PROCESS p_status_led;

   --------------------------------------------------------
   -- INPUT AGGREGATE
   --------------------------------------------------------
   wet_s    <= tms_spd_lim_stat_i      &                                          -- REQ: 199
               light_out_i             &
               tms_pb_i                &
               tms_spd_lim_overridden_i&
               tms_rst_i               &
               tms_penalty_stat_i      &
               tms_major_fault_i       &
               tms_minor_fault_i       &
               tms_depressed_i         &
               tms_suppressed_i        &
               tms_vis_warn_stat_i     &                                          -- REQ: 197
               buzzer_out_i;

   wet_fb_s <= tms_spd_lim_stat_fb_i   &                                          -- REQ: 199
               light_out_fb_i          &
               tms_pb_fb_i             &
               tms_spd_lim_overridden_fb_i &
               tms_rst_fb_i            &
               tms_penalty_stat_fb_i   &
               tms_major_fault_fb_i    &
               tms_minor_fault_fb_i    &
               tms_depressed_fb_i      &
               tms_suppressed_fb_i     &
               tms_vis_warn_stat_fb_i  &                                          -- REQ: 199
               buzzer_out_fb_i;

   dry_s    <= penalty1_out_i          &
               penalty2_out_i          &
               rly_out3_3V_i           &
               rly_out2_3V_i           &
               rly_out1_3V_i;

   dry_fb_s <= NOT penalty1_fb_i       &
               NOT penalty2_fb_i       &
               NOT rly_fb3_3V_i        &
               NOT rly_fb2_3V_i        &
               NOT rly_fb1_3V_i;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   wet_o          <= wet_out_r;
   wet_flt_o      <= wet_flt_r;

   dry_o          <= dry_msk_r;
   dry_flt_o      <= dry_flt_r;

   status_led_o   <= status_led_r;

END ARCHITECTURE beh;