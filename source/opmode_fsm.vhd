---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : opmode_fsm.vhd
-- Module      : VCU Timing System
-- Revision    : 1.8
-- Date/Time   : February 04, 2020
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Operation Mode FSM
---------------------------------------------------------------
-- History :
-- Revision 1.8 - February 04, 2020
--    - NRibeiro: Code coverage improvements
-- Revision 1.7 - January 22, 2020
--    - NRibeiro: added st_notst_i signal, cleaned 52.04 requirement references
-- Revision 1.6 - November 29, 2019
--    - NRibeiro: Applied CCN04 code changes
-- Revision 1.5 - March 19, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.4 - July 16, 2018
--    - AFernandes: Applied CCN02 code changes.
-- Revision 1.3 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.2 - March 08, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 27, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 17, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY opmode_fsm IS
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
END ENTITY opmode_fsm;


ARCHITECTURE beh OF opmode_fsm IS

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

   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   -- Operation Mode FSM
   TYPE   opmode_st_s IS (OPMODE_IDLE, OPMODE_MFAULT, OPMODE_TEST, OPMODE_DEPRESSED,
                          OPMODE_SUPPRESSED, OPMODE_NORMAL);
   SIGNAL opmode_curst_r      : opmode_st_s;
   SIGNAL opmode_nxtst_s      : opmode_st_s;

   SIGNAL opmode_prev_sup_r   : opmode_st_s;

   -- Opmode encoding (one-hot)
   SIGNAL opmode_s            : STD_LOGIC_VECTOR(4 DOWNTO 0);
   SIGNAL opmode_r            : STD_LOGIC_VECTOR(4 DOWNTO 0);

   -- VSU FSM Control
   SIGNAL vcu_tmr_hlt_s       : STD_LOGIC;
   SIGNAL vcu_tmr_hlt_r       : STD_LOGIC;

   -- Test mode request
   SIGNAL tst_req_re_s        : STD_LOGIC;
   SIGNAL mjr_flt_r           : STD_LOGIC;
   SIGNAL tst_req_r           : STD_LOGIC;
   SIGNAL dep_req_r           : STD_LOGIC;
   SIGNAL sup_req_r           : STD_LOGIC;

   -- Suppressed mode transitions (req 61)
   SIGNAL sup_tr_s            : STD_LOGIC;

   attribute syn_encoding : string;
   attribute syn_encoding of opmode_st_s : type is "johnson, safe";

BEGIN

   ----------------------------------------------------------------------------
   --  OPMODE FSM
   ----------------------------------------------------------------------------
   -- Clocked state transition
   p_opmode_fsm_st: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         opmode_curst_r   <= OPMODE_IDLE;
      ELSIF RISING_EDGE(clk_i) THEN
         opmode_curst_r   <= opmode_nxtst_s;
      END IF;
   END PROCESS p_opmode_fsm_st;

   -- Operation Mode FSM
   p_opmode_fsm: PROCESS(opmode_curst_r, mjr_flt_r, tst_req_r, dep_req_r,           -- REQ START: 46
                         sup_req_r, st_nosup_i, st_nonrm_i, st_notst_i,
                         opmode_prev_sup_r)
   BEGIN
      opmode_nxtst_s <= opmode_curst_r;
      vcu_tmr_hlt_s  <= '0';                                                        -- REQ: 119

      CASE opmode_curst_r IS                                                        -- REQ: 45

         WHEN OPMODE_MFAULT =>                                                      -- REQ: 45.01
            vcu_tmr_hlt_s  <= '1';

            -- Persistent state. No further transitions are allowed.

         WHEN OPMODE_TEST =>                                                        -- REQ: 45.02
            vcu_tmr_hlt_s  <= '1';
            IF    (mjr_flt_r = '1') THEN                                            -- REQ START: 110
               opmode_nxtst_s <= OPMODE_MFAULT;
            ELSIF (tst_req_r = '1') THEN                                            -- Exit Test Mode if all VCU
               -- keep state                                                           states were swept.
            ELSE                                                                    -- Exit Test Mod with Sup deasserted
               opmode_nxtst_s <= OPMODE_SUPPRESSED;                                 -- REQ: 61; OPL ID#160.
            END IF;                                                                 -- REQ END: 110

        WHEN OPMODE_SUPPRESSED =>                                                   -- REQ: 45.03

           vcu_tmr_hlt_s  <= '1';                                                   -- REQ: 54_56_115
           IF (mjr_flt_r = '1') THEN
              opmode_nxtst_s <= OPMODE_MFAULT;
           ELSIF (tst_req_r = '1') and (st_notst_i = '0') THEN                      -- REQ: 57_107
              opmode_nxtst_s <= OPMODE_TEST;
           ELSIF (( (sup_req_r = '1') AND (st_nosup_i = '0')) OR (st_nonrm_i = '1') ) THEN      -- REQ: 57. Guarantees correct state
              -- keep state                                                          when returns from Test
           ELSE
              opmode_nxtst_s <= opmode_prev_sup_r;                                  -- REQ: 61
           END IF;

        WHEN OPMODE_DEPRESSED =>                                                    -- REQ: 45.04

            IF    (mjr_flt_r = '1') THEN
               opmode_nxtst_s <= OPMODE_MFAULT;
            ELSIF (sup_req_r = '1') AND (st_nosup_i = '0') THEN                     -- REQ: 52_52.01_52.02_
               opmode_nxtst_s <= OPMODE_SUPPRESSED;                                 --      52.03_53_115
            ELSIF (dep_req_r = '1') THEN                                            -- Guarantees correct state
               -- keep state                                                           when returns form Test/Suppressed
            ELSE                                                                    -- REQ: 50
               opmode_nxtst_s <= OPMODE_NORMAL;
            END IF;


         WHEN OPMODE_NORMAL =>                                                      -- REQ: 45.05

            IF    (mjr_flt_r = '1') THEN
               opmode_nxtst_s <= OPMODE_MFAULT;
            ELSIF (sup_req_r = '1') AND (st_nosup_i = '0') THEN                     -- REQ: 52_52.01_52.02_
               opmode_nxtst_s <= OPMODE_SUPPRESSED;                                 --      52.03_115
            ELSIF (dep_req_r = '1') AND (st_nosup_i = '0') THEN
               opmode_nxtst_s <= OPMODE_DEPRESSED;
            END IF;

         WHEN OTHERS =>    -- OPMODE_IDLE                                           -- NR: fix for code coverage. After Power-up the FSM
            opmode_nxtst_s <= OPMODE_NORMAL;                                        --    is 1 clock cycle in this state, then jumps to Normal
                                                                                    --    state, where all transition conditions are evaluated.
      END CASE;
   END PROCESS p_opmode_fsm;                                                        -- REQ END: 46

   ----------------------------------------------------------------------------
   --  OPMODE
   ----------------------------------------------------------------------------
   -- Opmode encoding (one-hot)
   -- b4: MFAULT
   -- b3: TEST
   -- b2: DEPRESSED
   -- b1: SUPPRESSED
   -- b0: NORMAL
   p_opmode_enc: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         opmode_r   <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
            opmode_r   <= opmode_s;
      END IF;
   END PROCESS p_opmode_enc;
   WITH opmode_curst_r SELECT
      opmode_s   <= "10000" WHEN OPMODE_MFAULT,
                    "01000" WHEN OPMODE_TEST,
                    "00100" WHEN OPMODE_DEPRESSED,
                    "00010" WHEN OPMODE_SUPPRESSED,
                    "00001" WHEN OPMODE_NORMAL,
                    "00000" WHEN OTHERS;

   -- Store state prior to transition to Suppression Mode
   p_sup_prev_st: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         opmode_prev_sup_r      <= OPMODE_IDLE;
      ELSIF RISING_EDGE(clk_i) THEN
         IF (sup_tr_s = '1') THEN
            opmode_prev_sup_r <= opmode_curst_r;
         END IF;
      END IF;
   END PROCESS p_sup_prev_st;
   sup_tr_s <= '1' WHEN (opmode_curst_r /= OPMODE_SUPPRESSED)  AND
                        (opmode_curst_r /= OPMODE_TEST)        AND         -- Allways returns from test to suppressed. Avoid cycling
                        (opmode_nxtst_s = OPMODE_SUPPRESSED)   ELSE        -- Transiton to Suppressed Mode
               '0';


   ----------------------------------------------------------------------------
   --  TEST REQUEST CONTROL
   ----------------------------------------------------------------------------
   p_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         mjr_flt_r   <= '0';
         dep_req_r   <= '0';
         sup_req_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         mjr_flt_r   <= mjr_flt_i;
         dep_req_r   <= dep_req_i;
         sup_req_r   <= sup_req_i;
      END IF;
   END PROCESS p_reg;

   p_tst_req: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         tst_req_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         IF (tst_req_re_s = '1') THEN
            tst_req_r <= '1';
         ELSIF ((tmod_xt_i = '1') OR (tst_req_i = '0')) THEN
            tst_req_r <= '0';
         END IF;
      END IF;
   END PROCESS p_tst_req;

   edge_detector_i0 : edge_detector GENERIC MAP(G_EDGEPOLARITY => '1')
   PORT MAP(arst_i => arst_i, clk_i => clk_i, data_i => tst_req_i, edge_o => tst_req_re_s, valid_i => '1');

   ----------------------------------------------------------------------------
   --  VSU FSM CONTROL
   ----------------------------------------------------------------------------
   -- Halt VCU FSM
   p_vcu_hlt: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         vcu_tmr_hlt_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         vcu_tmr_hlt_r   <= vcu_tmr_hlt_s;
      END IF;
   END PROCESS p_vcu_hlt;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   -- Mode Request Assignment
   opmode_o       <= opmode_r;                                                      -- Current Mode Encoding (One-Hot)
   vcu_tmr_hlt_o  <= vcu_tmr_hlt_r;                                                 -- Halt VCU FSM

END ARCHITECTURE beh;