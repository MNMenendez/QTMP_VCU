---------------------------------------------------------------
-- Critical Software S.A.
---------------------------------------------------------------
-- Project     : ARTHCMT
-- Filename    : analog_if.vhd
-- Module      : Input IF
-- Revision    : 1.6
-- Date/Time   : May 31, 2021
-- Author      : JMonteiro, AFernandes, NRibeiro
---------------------------------------------------------------
-- Description : Analog Speed Encoder IF
---------------------------------------------------------------
-- History :
-- Revision 1.6 - May 31, 2021
--    - NRibeiro: [CCN05/CCN06] Applied code review comments.
-- Revision 1.5 - April 14, 2021
--    - NRibeiro: [CCN05] Added Generic for error_counter_filter module in order to
--                 differentiate REQ 202 vs REQ 201 on the maximum error counter
-- Revision 1.4 - March 14, 2019
--    - AFernandes: Applied CCN03 code changes.
-- Revision 1.3 - May 16, 2018
--    - JMonteiro: Applied code review comments for baseline 02.
-- Revision 1.2 - March 02, 2018
--    - JMonteiro: Applied code review comments.
-- Revision 1.1 - February 26, 2018
--    - JMonteiro: Added traceability to requirements version 0.29.
-- Revision 1.0 - January 29, 2018
--    - JMonteiro: Started.
---------------------------------------------------------------

---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY analog_if IS
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
      pulse500ms_i      : IN STD_LOGIC;

      ----------------------------------------------------------------------------
      --  Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_l3kmh_i       : IN STD_LOGIC;   -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_i       : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_a_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h
      spd_h23kmh_b_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 23km/h (dual counterpart)
      spd_h25kmh_a_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h25kmh_b_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h (dual counterpart)
      spd_h75kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i     : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      -- Processed speed reading
      spd_l3kmh_o       : OUT STD_LOGIC;  -- 4-20mA Speed Indicating < 3km/h
      spd_h3kmh_o       : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 3km/h
      spd_h23kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 23km/h
      spd_h25kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_o      : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_o     : OUT STD_LOGIC;  -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_o    : OUT STD_LOGIC;  -- 4-20mA Speed Indicating Speed Overrange

      -- Faults
      spd_urng_o        : OUT STD_LOGIC;  -- Analog Speed Under-Range reading
      spd_orng_o        : OUT STD_LOGIC;  -- Analog Speed Over-Range reading
      spd_err_o         : OUT STD_LOGIC   -- Analog Speed Error / Minor Fault (under/over range/inconsistent 
                                          --                                        6-bit value) (OPL ID#40)

   );
END ENTITY analog_if;


ARCHITECTURE beh OF analog_if IS

   --------------------------------------------------------
   -- COMPONENTS
   --------------------------------------------------------
   COMPONENT error_counter_filter IS
   GENERIC(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX      : NATURAL := 40
   );
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
   -- Input vectors
   SIGNAL spd_in_s      : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL spd_in_0_r    : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL spd_in_1_r    : STD_LOGIC_VECTOR(9 DOWNTO 0);
   SIGNAL spd_in_1_s    : STD_LOGIC_VECTOR(7 DOWNTO 0);

   -- Error flag mask
   SIGNAL msk_d0        : STD_LOGIC;
   SIGNAL msk_d1        : STD_LOGIC;

   -- Minor Fault Detect
   SIGNAl inv_spd_s0    : STD_LOGIC;
   SIGNAl inv_spd_s1    : STD_LOGIC;
   SIGNAL udr_rng_r     : STD_LOGIC;
   SIGNAL udr_rng_s0    : STD_LOGIC;
   SIGNAL udr_rng_s1    : STD_LOGIC;
   SIGNAL ovr_rng_r     : STD_LOGIC;
   SIGNAL ovr_rng_s0    : STD_LOGIC;
   SIGNAL ovr_rng_s1    : STD_LOGIC;
   SIGNAL spd_err_s     : STD_LOGIC;
   SIGNAL spd_err_r     : STD_LOGIC;

   -- Speed Processing
   SIGNAL spd_out_s     : STD_LOGIC_VECTOR(7 DOWNTO 0);
   SIGNAL spd_out_r     : STD_LOGIC_VECTOR(7 DOWNTO 0);

   -- 25km/h inputs fault
   SIGNAL spd_25km_flt_2_s0  : STD_LOGIC;
   SIGNAL spd_25km_flt_2_s1  : STD_LOGIC;

BEGIN

   -- Input synch
   p_synch: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         spd_in_0_r <= (OTHERS => '0');
         spd_in_1_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         spd_in_0_r <= spd_in_s;
         spd_in_1_r <= spd_in_0_r;
      END IF;
   END PROCESS p_synch;

   -- Delay line to mask effect of speed reset values
   -- while passing through synchronizer.
   p_msk: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         msk_d0 <= '0';
         msk_d1 <= '0';
      ELSIF RISING_EDGE(clk_i) THEN
         msk_d0 <= '1';
         msk_d1 <= msk_d0;
      END IF;
   END PROCESS p_msk;

   --------------------------------------------------------
   -- ANALOG FAULT DETECT 
   --------------------------------------------------------
   -- Latch under/over range faults.
   p_latch: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         udr_rng_r   <= '0';
         ovr_rng_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN                                                 -- Persistent failures
         IF (udr_rng_s1 = '1') THEN
            udr_rng_r   <= '1';
         END IF;
         IF (ovr_rng_s1 = '1') THEN
            ovr_rng_r   <= '1';
         END IF;
      END IF;
   END PROCESS p_latch;


   -- Interpret analog input speed
   p_flt: PROCESS(spd_in_1_s, msk_d1)
   BEGIN
      udr_rng_s0 <= '0';
      ovr_rng_s0 <= '0';
      inv_spd_s0 <= '0';

      CASE spd_in_1_s IS                                                            -- REQ: 40
         WHEN "00000000" =>                                                         -- REQ: 41.01
            udr_rng_s0 <= msk_d1 AND '1';                                           -- REQ: 42, Under Range
         WHEN "00000001" =>                                                         -- REQ: 41.02
            -- valid
         WHEN "00000011" =>                                                         -- REQ: 41.03
            -- valid
         WHEN "00000111" =>                                                         -- REQ: 41.04
            -- valid
         WHEN "00001111" =>                                                         -- REQ: 41.05
            -- valid
         WHEN "00011111" =>                                                         -- REQ: 41.06
            -- valid
         WHEN "00111111" =>                                                         -- REQ: 41.07
            -- valid
         WHEN "01111111" =>                                                         -- REQ: 41.08
            -- valid
         WHEN "11111111" =>                                                         -- REQ: 41.09
            ovr_rng_s0 <= msk_d1 AND '1';                                           -- REQ: 42, Over Range
         WHEN OTHERS =>
            inv_spd_s0 <= msk_d1 AND '1';                                           -- REQ: 43, Invalid speed reading
      END CASE;

   END PROCESS p_flt;
   spd_in_1_s <= spd_in_1_r(9) & --spd_over_spd_i
                 spd_in_1_r(8) & --spd_h110kmh_i
                 spd_in_1_r(7) & --spd_h90kmh_i
                 spd_in_1_r(6) & --spd_h75kmh_i
                 spd_in_1_r(5) & --spd_h25kmh_a_i                          -- Considering A for speed value (OPL#115)
                 spd_in_1_r(3) & --spd_h23kmh_a_i                          -- Considering A for speed value (OPL#115)
                 spd_in_1_r(1) & --spd_h3kmh_i
                 spd_in_1_r(0);  --spd_l3kmh_i;

   --------------------------------------------------------
   -- 25KM/H RANGE FAULT
   --------------------------------------------------------
   --REQ START: 96.  
   --  Equation:  spd_25km_fault = (spd_h25kmh_a_i OR spd_h25kmh_b_i) AND (spd_h23kmh_a_i NAND spd_h23kmh_b_i)
   spd_25km_flt_2_s0 <= msk_d1 AND ((spd_in_1_r(5) OR spd_in_1_r(4)) AND (spd_in_1_r(3) NAND spd_in_1_r(2)));
   --REQ END

   --------------------------------------------------------
   -- FAULT ERROR COUNTERS
   --------------------------------------------------------
   --REQ START: 202
   --
   -- [CCN05]: Added Generic for error_counter_filter module
   --
   error_counter_filter_i0: error_counter_filter
   GENERIC MAP(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX         => 60
   )     
   PORT MAP (
         arst_i               => arst_i,
         clk_i                => clk_i,
         valid_i              => pulse500ms_i,
         fault_i              => udr_rng_s0,
         fault_o              => udr_rng_s1
   );

   error_counter_filter_i1: error_counter_filter
   GENERIC MAP(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX         => 60
   )        
   PORT MAP (
         arst_i               => arst_i,
         clk_i                => clk_i,
         valid_i              => pulse500ms_i,
         fault_i              => ovr_rng_s0,
         fault_o              => ovr_rng_s1
   );

   error_counter_filter_i2: error_counter_filter
   GENERIC MAP(
      -- Maximum number of errors counted before an output and permanent fault is notified   
      G_CNT_ERROR_MAX         => 60
   )        
   PORT MAP (
         arst_i               => arst_i,
         clk_i                => clk_i,
         valid_i              => pulse500ms_i,
         fault_i              => inv_spd_s0,
         fault_o              => inv_spd_s1
   );

   error_counter_filter_i3: error_counter_filter
   GENERIC MAP(
      -- Maximum number of errors counted before an output and permanent fault is notified
      G_CNT_ERROR_MAX         => 60
   )        
   PORT MAP (
         arst_i               => arst_i,
         clk_i                => clk_i,
         valid_i              => pulse500ms_i,
         fault_i              => spd_25km_flt_2_s0,
         fault_o              => spd_25km_flt_2_s1
   );
   --REQ END: 202 

   --------------------------------------------------------
   -- AGREGATED ANALOG FAULT DETECT
   --------------------------------------------------------
   -- Latch analog speed error fault
   p_flt_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         spd_err_r   <= '0';
      ELSIF RISING_EDGE(clk_i) THEN                                                 -- Persistent failure
         IF (spd_err_s = '1') THEN
            spd_err_r   <= '1';
         END IF;
      END IF;
   END PROCESS p_flt_reg;
   spd_err_s  <= udr_rng_s1 OR                                                       -- Under Range condition
                 ovr_rng_s1 OR                                                       -- Over Range condition
                 inv_spd_s1 OR                                                       -- Unexpected speed reading
                 spd_25km_flt_2_s1;                                                  -- REQ 179 (OPL#114)

   --------------------------------------------------------
   -- PROCESS SPEED READING
   --------------------------------------------------------
   p_spd_reg: PROCESS(clk_i, arst_i)
   BEGIN
      IF (arst_i = '1') THEN
         spd_out_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_i) THEN
         spd_out_r <= spd_out_s;
      END IF;
   END PROCESS p_spd_reg;
   spd_out_s <= "01111111" WHEN spd_err_r = '1' ELSE                                -- REQ: 42_43
                spd_in_1_s;

   --------------------------------------------------------
   -- INPUT AGGREGATE
   --------------------------------------------------------
   spd_in_s <= spd_over_spd_i &
               spd_h110kmh_i  &
               spd_h90kmh_i   &
               spd_h75kmh_i   &
               spd_h25kmh_a_i &
               spd_h25kmh_b_i &                                         -- Only used for 25km/h range fault (OPL#115)
               spd_h23kmh_a_i &
               spd_h23kmh_b_i &                                         -- Only used for 25km/h range fault (OPL#115)
               spd_h3kmh_i    &
               spd_l3kmh_i;

   --------------------------------------------------------
   -- OUTPUTS
   --------------------------------------------------------
   -- Processed Speed
   spd_l3kmh_o    <= spd_out_r(0);
   spd_h3kmh_o    <= spd_out_r(1);
   spd_h23kmh_o   <= spd_out_r(2);
   spd_h25kmh_o   <= spd_out_r(3);
   spd_h75kmh_o   <= spd_out_r(4);
   spd_h90kmh_o   <= spd_out_r(5);
   spd_h110kmh_o  <= spd_out_r(6);
   spd_over_spd_o <= spd_out_r(7);

   -- Faults
   spd_urng_o     <= udr_rng_r;
   spd_orng_o     <= ovr_rng_r;
   spd_err_o      <= spd_err_r;

END ARCHITECTURE beh;