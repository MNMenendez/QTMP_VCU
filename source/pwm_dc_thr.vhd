---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : pwm_dc_thr.vhd
-- Module      : pwm_dc_thr
-- Revision    : 1.4
-- Date/Time   : May 31, 2021
-- Author      : AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Interpret DC value
---------------------------------------------------------------
-- History :
-- Revision 1.4 - May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.3 - May 24, 2021
--    - NRibeiro: [CCN05/CCN06] Change Request, Changed No_Power range: max value was changed from 18.89% to
--                23%, as now stated in REQ 85
-- Revision 1.2 - April 14, 2021
--    - NRibeiro: [CCN05] Applied/Updated with CCN05 changes related to REQ 37 and REQ 85
-- Revision 1.1 - November 29, 2019
--    - NRibeiro: Applied code changes for CCN04.
-- Revision 1.0 - April 05, 2019
--    - AFernandes: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY pwm_dc_thr IS
   PORT
   (
      ----------------------------------------------------------------------------
      --  Generic ports
      ----------------------------------------------------------------------------
      arst_i            : IN STD_LOGIC;                        -- Global (asynch) reset
      clk_i             : IN STD_LOGIC;                        -- Global clk

      ----------------------------------------------------------------------------
      --  PWM Inputs
      ----------------------------------------------------------------------------
      pwm_duty_i        : IN STD_LOGIC_VECTOR(9 DOWNTO 0);     -- PWM DC
      pwm_duty_valid_i  : IN STD_LOGIC;                        -- Signals valid PWM DC reading
      pwm_fault_i       : IN STD_LOGIC;                        -- PWM fault

      ----------------------------------------------------------------------------
      --     Fault Inhibit Input
      ----------------------------------------------------------------------------
      inhibit_fault_i    : IN STD_LOGIC;                        -- Inhibit generation of PWM faults

      ----------------------------------------------------------------------------
      --  OUTPUTS
      ----------------------------------------------------------------------------
      pwm_duty_o        : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);    -- PWM DC
      pwm_duty_valid_o  : OUT STD_LOGIC;                       -- Signals valid PWM DC reading
      pwm_update_o      : OUT STD_LOGIC;                       -- Signals PWM DC Update

      pwm_fault_o       : OUT STD_LOGIC;                       -- PWM0 fault
      mc_no_pwr_o       : OUT STD_LOGIC                        -- MC = No Power
   );
END ENTITY pwm_dc_thr;


ARCHITECTURE beh OF pwm_dc_thr IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------
   COMPONENT pwm_counter_error IS
   PORT (
      -- Clock and reset
      arst_i               : IN  STD_LOGIC;
      clk_i                : IN  STD_LOGIC;
      -- valid PWM input
      valid_i              : IN  STD_LOGIC;
      -- error input
      fault_i              : IN  STD_LOGIC;
      -- mask output
      mask_o               : OUT STD_LOGIC;
      -- Permanent fault output
      fault_o              : OUT STD_LOGIC
   );
   END COMPONENT pwm_counter_error;

   --------------------------------------------------------
   -- CONSTANTS
   --------------------------------------------------------            
   -- [CCN05]     : Invalid Ranges 
   
   -- (0-5%)      : Invalid Range (REQ 37.01)
   CONSTANT C_MNINVALID_MAX   : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED( 26,10);   
   
   -- (95%-100%)  : Invalid Range (REQ 37.08)
   CONSTANT C_MXINVALID_MIN   : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED(486,10);   
   
   -- [CCN05] CR  : No-Power Ranges (REQ 85)                                    
   
   -- (5%)        : No Power Brake MIN                --  round(511*( 5.0)/100 =  25.55) =  26
   CONSTANT C_NOPWR_MIN       : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED( 26,10);   
   
   -- (23%)       : No Power Brake MAX                --  round(511*(23.0)/100 = 117.53) = 118
   CONSTANT C_NOPWR_MAX       : UNSIGNED( 9 DOWNTO 0) := TO_UNSIGNED(118,10);   
   
   --------------------------------------------------------
   -- SIGNALS
   --------------------------------------------------------
   SIGNAL pwm_duty_s       : UNSIGNED(9 DOWNTO 0);
   SIGNAL pwm_duty_r       : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL pwm_update_r     : STD_LOGIC;
   SIGNAL pwm_duty_valid_r : STD_LOGIC;

   SIGNAL dc_inv_s         : STD_LOGIC;
   SIGNAL dc_inv_r         : STD_LOGIC;
   SIGNAL no_pwr_thres_s   : STD_LOGIC;
   SIGNAL no_pwr_thres_r   : STD_LOGIC;

   SIGNAL mc_no_pwr_s      : STD_LOGIC;
   SIGNAL mc_no_pwr_r      : STD_LOGIC;

   SIGNAL pwm_mask_s       : STD_LOGIC;
   SIGNAL dc_valid_r       : STD_LOGIC;
   SIGNAL pwm_temp_fault_s : STD_LOGIC;
   SIGNAL pwm_per_fault_s  : STD_LOGIC;

   SIGNAL pwm_duty_valid_i_r1 : STD_LOGIC;
   SIGNAL pwm_duty_valid_i_r2 : STD_LOGIC;
   SIGNAL pwm_duty_valid_i_r3 : STD_LOGIC;
   SIGNAL pwm_duty_valid_i_r4 : STD_LOGIC;
   SIGNAL pwm_mask_r          : STD_LOGIC;

BEGIN
   --------------------------------------------------------
   -- INPUT DC VALID
   --------------------------------------------------------

   --NRibeiro 2019/11/26: pwm_mask_s is updated acordingly to the input 3 clock cycles later than
   --                     pwm_duty_valid_i becomes active, so we must only update the output signals
   --                     4 clock cycles after the pwm_duty_valid_i is active
   --
   --                     Also due to REQ: 215, registers pwm_update_r and pwm_duty_valid_r
   --                     cannot be set to '1' right after pwm_mask_s deasserts; needs to wait for
   --                     another pwm_duty_valid_i_r4 tick. This is the reason why the condition
   --                     to set those registers to '1' also make use of pwm_mask_r (delayed version
   --                     of pwm_mask_s by one pwm_duty_valid_i tick)
   p_valid_s: PROCESS(arst_i,clk_i)
   BEGIN
      IF (arst_i='1') THEN
         pwm_duty_valid_i_r1   <= '0';
         pwm_duty_valid_i_r2   <= '0';
         pwm_duty_valid_i_r3   <= '0';
         pwm_duty_valid_i_r4   <= '0';
         pwm_duty_valid_r      <= '0';
         pwm_update_r          <= '0';
         pwm_duty_r            <= (OTHERS => '0');
         pwm_mask_r            <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         pwm_duty_valid_i_r1   <= pwm_duty_valid_i;
         pwm_duty_valid_i_r2   <= pwm_duty_valid_i_r1;
         pwm_duty_valid_i_r3   <= pwm_duty_valid_i_r2;
         pwm_duty_valid_i_r4   <= pwm_duty_valid_i_r3;

         pwm_duty_r            <= pwm_duty_i;

         IF (pwm_duty_valid_i_r4 = '1') THEN
            pwm_mask_r          <= pwm_mask_s;
            IF (pwm_mask_s = '0')  and (pwm_mask_r = '0') THEN    -- * PWM data valid and not masked
                pwm_update_r    <= '1';
                pwm_duty_valid_r<= '1';
            ELSE
                pwm_update_r    <= '0';
                pwm_duty_valid_r<= '0';
            END IF;
         ELSIF (pwm_mask_s = '1' OR pwm_fault_i = '1') THEN
            pwm_update_r        <= '0';
            pwm_duty_valid_r    <= '0';
         ELSE
            pwm_update_r        <= '0';
         END IF;
      END IF;
   END PROCESS p_valid_s;

   pwm_duty_s <= UNSIGNED(pwm_duty_i);
   

   --------------------------------------------------------
   -- DC INVALID
   --------------------------------------------------------
   -- [CCN05] PWM DC Thresholds definitions were updated 
   --           Invalid ranges are defined in REQ 37.01 and REQ 37.08  
   dc_inv_s                     <= '1' WHEN ((pwm_duty_s < C_MNINVALID_MAX) OR (pwm_duty_s >= C_MXINVALID_MIN)) ELSE  
                                   '0';

   p_dc_inv_i0: PROCESS(clk_i, arst_i)                                                 -- REQ: 82
   BEGIN
      IF (arst_i = '1') THEN
         dc_inv_r   <= '0';
         dc_valid_r <= '0';
      ELSIF RISING_EDGE(clk_i) THEN                                                    -- DC fault
         IF (pwm_duty_valid_i = '1') THEN
            IF (dc_inv_s = '1') THEN
               dc_inv_r <= '1';
            ELSE
               dc_valid_r <= '1';
            END IF;
         ELSE
           dc_inv_r  <= '0';
           dc_valid_r <= '0';
         END IF;
      END IF;
   END PROCESS p_dc_inv_i0;

   pwm_temp_fault_s <= (pwm_fault_i OR dc_inv_r) AND NOT inhibit_fault_i;

   --------------------------------------------------------
   -- MC NO POWER
   --------------------------------------------------------
   -- [CCN05] PWM DC Thresholds were redefined for No-Power
   --     affecting REQ 85

   no_pwr_thres_s                <= '1' WHEN (pwm_duty_s >= C_NOPWR_MIN) AND (pwm_duty_s < C_NOPWR_MAX) ELSE 
                                    '0';
      
   p_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         no_pwr_thres_r          <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         no_pwr_thres_r          <= no_pwr_thres_s;
      END IF;
   END PROCESS p_reg;   
   
   mc_no_pwr_s                   <= no_pwr_thres_r    OR                           -- [CCN05] REQ 85
                                    pwm_per_fault_s;                               -- REQ: 194.

   p_mc: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         mc_no_pwr_r             <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         mc_no_pwr_r             <= mc_no_pwr_s;
      END IF;
   END PROCESS p_mc; 
   
   --------------------------------------------------------
   -- PWM ERROR COUNTER
   --------------------------------------------------------

   -- REQ START: 191_192_193_215
   pwm_counter_error_u: pwm_counter_error
   PORT MAP (
         arst_i      => arst_i,
         clk_i       => clk_i,
         valid_i     => dc_valid_r,
         fault_i     => pwm_temp_fault_s,
         mask_o      => pwm_mask_s,
         fault_o     => pwm_per_fault_s
   );
   -- REQ END: 191_192_193_215
   
   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   pwm_duty_o        <= pwm_duty_r;
   pwm_duty_valid_o  <= pwm_duty_valid_r;
   pwm_update_o      <= pwm_update_r;

   pwm_fault_o       <= pwm_per_fault_s;
   mc_no_pwr_o       <= mc_no_pwr_r;

END ARCHITECTURE beh;