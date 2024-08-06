---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : opmode_req.vhd
-- Module      : VCU Timing System
-- Revision    : 1.7
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Operation Mode Request Decoder
---------------------------------------------------------------
-- History :
-- Revision 1.7 - May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.6 - May 19, 2021
--    - NRibeiro: [CCN06] For completeness, the "zero_spd_r = '1'" was added to the set condition
--                  of the "Test Mode Request"
-- Revision 1.5 - April 30, 2021
--    - NRibeiro: [CCN06] Update conditions for entering and leaving Test Mode. (Req 46)
-- Revision 1.4 - March 19, 2019
--    - AFernandes: Applied CCN03 changes.
-- Revision 1.3 - March 02, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.2 - February 27, 2018
--    - JMonteiro: Removed NOT from cab_act_d and not_isol_d from sup_req_s.
--                 Added cab_act_d to tmod_req_s logic equation.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 15, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY opmode_req IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
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
      digi_zero_spd_i      : IN STD_LOGIC;                     -- Digital zero Speed (external input)
      driverless_i         : IN STD_LOGIC;                     -- Driverless (external input)
      anlg_spd_i           : IN STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Aggregated speed signals
      vigi_pb_i            : IN STD_LOGIC;                     -- Vigilance Push Button
      tmod_xt_i            : IN STD_LOGIC;                     -- Exit test mode 

      ----------------------------------------------------------------------------
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      anlg_spd_err_i       : IN STD_LOGIC;                     -- Analog Speed Error (OPL ID#40)
      digi_zero_spd_flt_i  : IN STD_LOGIC;                     -- Digital zero speed fault, processed external input

      ----------------------------------------------------------------------------
      --  Notification Outputs
      ----------------------------------------------------------------------------
      zero_spd_o           : OUT STD_LOGIC;                    -- Claculated Zero Speed

      ----------------------------------------------------------------------------
      --  Mode Request Outputs
      ----------------------------------------------------------------------------
      sup_req_o            : OUT STD_LOGIC;                    -- Suppression Request
      dep_req_o            : OUT STD_LOGIC;                    -- Depression Request
      tst_req_o            : OUT STD_LOGIC                     -- Test Mode Request

    );
END ENTITY opmode_req;


ARCHITECTURE beh OF opmode_req IS

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------
   CONSTANT C_CTR_ACK_HLD  : UNSIGNED(12 DOWNTO 0) := TO_UNSIGNED(6000,13);

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Delay registers
   SIGNAL bcp_75_d         : STD_LOGIC;
   SIGNAL cab_act_d        : STD_LOGIC;
   SIGNAL cbtc_d           : STD_LOGIC;
   SIGNAL driverless_d     : STD_LOGIC;

   -- Zero Speed Logic
   SIGNAL zero_spd_s       : STD_LOGIC;
   SIGNAL zero_spd_r       : STD_LOGIC;
   SIGNAL zero_spd_fault_s : STD_LOGIC;

   -- Registers
   SIGNAL sup_req_s        : STD_LOGIC;
   SIGNAL sup_req_r        : STD_LOGIC;

   SIGNAL dep_req_s        : STD_LOGIC;
   SIGNAL dep_req_r        : STD_LOGIC;

   SIGNAL tmod_req_s       : STD_LOGIC;
   SIGNAL tmod_req_r       : STD_LOGIC;
   SIGNAL tmod_req_ff_r    : STD_LOGIC;
   SIGNAL ctr_ack_hld_s    : UNSIGNED(12 DOWNTO 0);
   SIGNAL ctr_ack_hld_r    : UNSIGNED(12 DOWNTO 0);
   SIGNAL vpb_hld_s        : STD_LOGIC;


   -- Analog Zero Speed
   SIGNAL anlg_zero_spd_s  : STD_LOGIC;


BEGIN

    -- Determine Zero Speed condition
   p_zero_spd: PROCESS(clk_i,arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         zero_spd_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         zero_spd_r <= zero_spd_s;
      END IF;
   END PROCESS p_zero_spd;
   zero_spd_s  <= anlg_zero_spd_s AND digi_zero_spd_i AND
                 (NOT zero_spd_fault_s);                                                 -- REQ: 44
   zero_spd_fault_s <= (anlg_spd_err_i OR digi_zero_spd_flt_i);

   -- 4-20mA (analog reading) Zero Speed
   anlg_zero_spd_s <= '1' WHEN anlg_spd_i = "00000001" ELSE
                      '0';

    -- Delay Registers
   p_delay: PROCESS(clk_i,arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         bcp_75_d          <= '0';
         cab_act_d         <= '0';
         cbtc_d            <= '0';
         driverless_d      <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         bcp_75_d          <= bcp_75_i;
         cab_act_d         <= cab_act_i;
         cbtc_d            <= cbtc_i;
         driverless_d      <= driverless_i;
      END IF;
   END PROCESS p_delay;

   ----------------------------------------------------------------------------
   --  MODE REQUEST
   ----------------------------------------------------------------------------

   -- Suppression Mode Request                                                -- CCN03 change
   p_sup_req: PROCESS(clk_i,arst_i)                                           -- REQ START: 46
   BEGIN                                                                      
      IF (arst_i = '1') THEN                                                  
         sup_req_r <= '0';                                                    
      ELSIF RISING_EDGE(clk_i) THEN                                           
         sup_req_r <= sup_req_s;                                              
      END IF;                                                                 
   END PROCESS p_sup_req;                                                     
   sup_req_s <= driverless_d                 OR                               -- REQ: 100
                (bcp_75_d AND zero_spd_r)    OR
                (cab_act_d);                                                  -- Means cab is inactive (active Low)

   -- Depression Request
   p_dep_req: PROCESS(clk_i,arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         dep_req_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         dep_req_r <= dep_req_s;
      END IF;
   END PROCESS p_dep_req;
   dep_req_s <= cbtc_d;                                                       -- CCN03

   -- Test Mode Request. CCN03
   p_ctr_ack_hld: PROCESS(clk_i, arst_i)                                      -- VPB counter
   BEGIN
      IF (arst_i = '1') THEN
         ctr_ack_hld_r <= C_CTR_ACK_HLD;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (vigi_pb_i = '0') THEN                                            -- VPB disabled
            ctr_ack_hld_r <= C_CTR_ACK_HLD;
         ELSIF (pulse500us_i = '1') THEN
            ctr_ack_hld_r <= ctr_ack_hld_s;
         END IF;
      END IF;
   END PROCESS p_ctr_ack_hld;

   ctr_ack_hld_s    <= ctr_ack_hld_r - 1 WHEN (ctr_ack_hld_r /= 0) ELSE ctr_ack_hld_r;

   vpb_hld_s <= '1' WHEN (ctr_ack_hld_r = 0) ELSE '0';                       -- VPB > 3 seconds

   
   -- [CCN06] REQ: 46 new conditions for entering and leaving Test Mode
   -- NOTE: (cab_act_d = '0') means CAB Active due to this pin being active low and
   --       (cab_act_d = '1') menas CAB Inactive.  
   p_tmod_ff_req: PROCESS(clk_i,arst_i)                                      -- Latch 
   BEGIN
      IF (arst_i = '1') THEN
         tmod_req_ff_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF ( (tmod_xt_i = '1') OR (sup_req_r = '0') OR (zero_spd_r = '0') OR (cab_act_d = '1') ) THEN 
            tmod_req_ff_r <= '0';
         ELSIF ( (vpb_hld_s = '1') AND (sup_req_r = '1') AND (zero_spd_r = '1') AND (cab_act_d = '0') ) THEN 
            tmod_req_ff_r <= '1';
         END IF;
      END IF;
   END PROCESS p_tmod_ff_req;

   p_tmod_req: PROCESS(clk_i,arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         tmod_req_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         tmod_req_r <= tmod_req_s;
      END IF;
   END PROCESS p_tmod_req;
   
   tmod_req_s <= tmod_req_ff_r;                                               -- REQ: 107

                                                                              -- REQ END: 46
   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   -- Notification Outputs
   zero_spd_o  <= zero_spd_r;

   -- Mode Request Assignment
   sup_req_o   <= sup_req_r;
   dep_req_o   <= dep_req_r;
   tst_req_o   <= tmod_req_r;

END ARCHITECTURE beh;