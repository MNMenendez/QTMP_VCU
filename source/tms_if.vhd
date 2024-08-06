---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : tms_if.vhd
-- Module      : TMS IF
-- Revision    : 1.6
-- Date/Time   : December 11, 2019
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : TMS IF
---------------------------------------------------------------
-- History :
-- Revision 1.6 - December 11, 2019
--    - NRibeiro: Code/Comments cleanup.
-- Revision 1.5 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes.
-- Revision 1.4 - March 26, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.3 - July 27, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.2 - March 05, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - February 15, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;


ENTITY tms_if IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Clock/Reset Inputs
      ----------------------------------------------------------------------------
      arst_i               : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i                : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  Push Button Inputs
      ----------------------------------------------------------------------------
      vigi_pb_i            : IN STD_LOGIC;                        -- VPB post-filtering
      spd_lim_overridden_i : IN STD_LOGIC;                        -- Speed Limit Override post-filtering   

      ----------------------------------------------------------------------------
      --  Penalty Brake Actuation Inputs
      ----------------------------------------------------------------------------
      penalty1_out_i       : IN STD_LOGIC;                        -- Penalty Brake 1 Actuation dry 4
      penalty2_out_i       : IN STD_LOGIC;                        -- Penalty Brake 2 Actuation dry 4

      ----------------------------------------------------------------------------
      --  Fault Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i            : IN STD_LOGIC;                        -- Major Fault
      mnr_flt_i            : IN STD_LOGIC;                        -- Minor Fault

      ----------------------------------------------------------------------------
      --  Operation Modes
      ----------------------------------------------------------------------------
      opmode_dep_i         : IN STD_LOGIC;                        -- Indicates VCU in Depressed Operation Mode
      opmode_sup_i         : IN STD_LOGIC;                        -- Indicates VCU in Suppressed Operation Mode
      opmode_nrm_i         : IN STD_LOGIC;                        -- Indicates VCU in Normal Operation Mode

      ----------------------------------------------------------------------------
      --  VCU FSM Inputs
      ----------------------------------------------------------------------------
      vcu_rst_i            : IN STD_LOGIC;                        -- VCU Timing FSM Rst

      ----------------------------------------------------------------------------
      --  Speed Limit Status Inputs
      ----------------------------------------------------------------------------
      spd_lim_st_i         : IN STD_LOGIC;                        -- Indicates speed limit timer running
      vis_warn_stat_i      : IN STD_LOGIC;                        -- Indicates Visble Light Warning Status on
      ----------------------------------------------------------------------------
      --  TMS Outputs
      ----------------------------------------------------------------------------
      tms_pb_o             : OUT STD_LOGIC;                       -- Mirror VPB input post filtering
      tms_spd_lim_overridden_o : OUT STD_LOGIC;                   -- Mirror Speed Limit Override input post filtering 
      tms_rst_o            : OUT STD_LOGIC;                       -- VCU reset, single 500mS pulse
      tms_penalty_stat_o   : OUT STD_LOGIC;                       -- Mirror penalty brake outputs.
      tms_major_fault_o    : OUT STD_LOGIC;                       -- Mirror Major Fault
      tms_minor_fault_o    : OUT STD_LOGIC;                       -- Asserted when ANY minor fault occurs.
      tms_depressed_o      : OUT STD_LOGIC;                       -- Asserted when the VCU is in depressed mode
      tms_suppressed_o     : OUT STD_LOGIC;                       -- Asserted when the VCU is in suppressed mode
      tms_normal_o         : OUT STD_LOGIC;                       -- Asserted when the VCU is in normal mode
      tms_spd_lim_stat_o   : OUT STD_LOGIC;                       -- Asserted when speed limit timer running
      tms_vis_warn_stat_o  : OUT STD_LOGIC                        -- Asserted when the Visible Warning Status is on
   );
END ENTITY tms_if;


ARCHITECTURE beh OF tms_if IS

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   SIGNAL tms_pb_r                  : STD_LOGIC;
   SIGNAL tms_spd_lim_overridden_r  : STD_LOGIC;
   SIGNAL tms_rst_r                 : STD_LOGIC;
   SIGNAL tms_penalty_stat_r        : STD_LOGIC;
   SIGNAL tms_major_fault_r         : STD_LOGIC;
   SIGNAL tms_minor_fault_r         : STD_LOGIC;
   SIGNAL tms_depressed_r           : STD_LOGIC;
   SIGNAL tms_suppressed_r          : STD_LOGIC;
   SIGNAL tms_normal_r              : STD_LOGIC;
   SIGNAL tms_spd_lim_stat_r        : STD_LOGIC;
   SIGNAL tms_vis_warn_stat_r       : STD_LOGIC;

BEGIN

   --------------------------------------------------------
   -- OUTPUT REGISTERS
   --------------------------------------------------------
   p_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         tms_pb_r                   <= '0';
         tms_spd_lim_overridden_r   <= '0';
         tms_rst_r                  <= '0';
         tms_penalty_stat_r         <= '0';
         tms_major_fault_r          <= '0';
         tms_minor_fault_r          <= '0';
         tms_depressed_r            <= '0';
         tms_suppressed_r           <= '0';
         tms_normal_r               <= '0';
         tms_spd_lim_stat_r         <= '0';
         tms_vis_warn_stat_r        <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         tms_pb_r                   <= vigi_pb_i;                                          -- REQ: 139_144_145 (OPL#97)
         tms_spd_lim_overridden_r   <= spd_lim_overridden_i;                               --
         tms_rst_r                  <= vcu_rst_i;                                          -- REQ: 139_148_149 (OPL#96)
         tms_penalty_stat_r         <= penalty1_out_i OR penalty2_out_i;                   -- REQ: 139_151_152
         tms_major_fault_r          <= mjr_flt_i;                                          -- REQ: 139_153_154
         tms_minor_fault_r          <= mnr_flt_i;                                          -- REQ: 139_155_156_88
         tms_depressed_r            <= opmode_dep_i;                                       -- REQ: 139_157_158
         tms_suppressed_r           <= opmode_sup_i;                                       -- REQ: 139_159_160
         tms_normal_r               <= opmode_nrm_i;                                       -- REQ: 139
         tms_spd_lim_stat_r         <= spd_lim_st_i;                                       -- REQ: 199
         tms_vis_warn_stat_r        <= vis_warn_stat_i;                                    -- REQ: 197
      END IF;
   END PROCESS p_reg;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   tms_pb_o                         <= tms_pb_r;
   tms_spd_lim_overridden_o         <= tms_spd_lim_overridden_r; 
   tms_rst_o                        <= tms_rst_r;
   tms_penalty_stat_o               <= (NOT tms_penalty_stat_r);                           -- CCN03 change
   tms_major_fault_o                <= tms_major_fault_r;
   tms_minor_fault_o                <= tms_minor_fault_r;
   tms_depressed_o                  <= tms_depressed_r;
   tms_suppressed_o                 <= tms_suppressed_r;
   tms_normal_o                     <= tms_normal_r;
   tms_spd_lim_stat_o               <= tms_spd_lim_stat_r;
   tms_vis_warn_stat_o              <= tms_vis_warn_stat_r;

END ARCHITECTURE beh;