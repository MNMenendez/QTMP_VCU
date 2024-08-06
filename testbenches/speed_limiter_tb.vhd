
---- Standard library
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;


ENTITY speed_limiter_tb IS
END ENTITY speed_limiter_tb;


ARCHITECTURE beh OF speed_limiter_tb IS

	COMPONENT speed_limiter IS
      PORT (
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
      --  Processed (Fault) Inputs
      ----------------------------------------------------------------------------
      mjr_flt_i         : IN STD_LOGIC;   -- Major Fault

      ----------------------------------------------------------------------------
      --  Analog Inputs (Speed)
      ----------------------------------------------------------------------------
      spd_h25kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 25km/h
      spd_h75kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 75km/h
      spd_h90kmh_i      : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 90km/h
      spd_h110kmh_i     : IN STD_LOGIC;   -- 4-20mA Speed Indicating > 100km/h
      spd_over_spd_i    : IN STD_LOGIC;   -- 4-20mA Speed Indicating Speed Overrange
		
		
		----------------------------------------------------------------------------
      --  Zero Speed Input (TOM Change)
      ----------------------------------------------------------------------------
		zero_spd_i        : IN STD_LOGIC;                        -- Zero Speed Input

      ----------------------------------------------------------------------------
      --  Outputs
      ----------------------------------------------------------------------------
      rly_out4_3V_o     : OUT STD_LOGIC;  -- Speed Limit Exceeded 2
      rly_out3_3V_o     : OUT STD_LOGIC;  -- Speed Limit Exceeded 1
      spd_lim_st_o      : OUT STD_LOGIC   -- Speed Limit Status Output 
      );
   END COMPONENT speed_limiter;
	
	COMPONENT edge_detector IS
      GENERIC (
         G_EDGEPOLARITY:  STD_LOGIC := '1'
      );
      PORT (
         arst_i:           IN  STD_LOGIC; 
         clk_i:            IN  STD_LOGIC;
         valid_i:          IN  STD_LOGIC;
         data_i:           IN  STD_LOGIC;
         edge_o:           OUT STD_LOGIC
      );
   END COMPONENT edge_detector;
	
	-----------------------------------------------------------
	-- 	Test Signals
	-----------------------------------------------------------
	SIGNAL arst_s        	: STD_LOGIC;
   SIGNAL clk_s        		: STD_LOGIC := '0';

   SIGNAL pulse500ms_s  	: STD_LOGIC;

   SIGNAL spd_lim_s  		: STD_LOGIC;

   SIGNAL mjr_flt_s     	: STD_LOGIC;

   SIGNAL spd_h25kmh_s  	: STD_LOGIC;
   SIGNAL spd_h75kmh_s  	: STD_LOGIC;
   SIGNAL spd_h90kmh_s  	: STD_LOGIC;
   SIGNAL spd_h110kmh_s 	: STD_LOGIC;
   SIGNAL spd_over_spd_s	: STD_LOGIC;
		
	SIGNAL zero_spd_s    	: STD_LOGIC;

   SIGNAL rly_out4_3V_s 	: STD_LOGIC;
   SIGNAL rly_out3_3V_s 	: STD_LOGIC;
   SIGNAL spd_lim_st_s  	: STD_LOGIC;
	
	CONSTANT C_CNT_HIGH_BIT    : NATURAL  := 14;         -- Maximum counter bits
	
	SIGNAL cnt_r            : UNSIGNED( ( C_CNT_HIGH_BIT - 0 ) DOWNTO 0);

BEGIN

	-- Tick counter
   p_tickcnt: PROCESS(arst_s,clk_s)
   BEGIN
      IF arst_s='1' THEN
         cnt_r <= (OTHERS => '0');
      ELSIF RISING_EDGE(clk_s) THEN
         cnt_r <= cnt_r + 1;
      END IF;
   END PROCESS p_tickcnt;
	
	edge_detector_i0: edge_detector
   PORT MAP (
      arst_i   => arst_s,
      clk_i    => clk_s,
      valid_i  => '1',
      data_i   => cnt_r(4),
      edge_o   => pulse500ms_s
   );
	
	

	speed_limiter_i0: speed_limiter
   PORT MAP
   (
      arst_i            => arst_s,
      clk_i             => clk_s,

      pulse500ms_i      => pulse500ms_s,

      spd_lim_i         => spd_lim_s,

      mjr_flt_i         => mjr_flt_s,

      spd_h25kmh_i      => spd_h25kmh_s,
      spd_h75kmh_i      => spd_h75kmh_s,
      spd_h90kmh_i      => spd_h90kmh_s,
      spd_h110kmh_i     => spd_h110kmh_s,
      spd_over_spd_i    => spd_over_spd_s,
		
		zero_spd_i			=> zero_spd_s,			-- TOM Change

      rly_out4_3V_o     => rly_out4_3V_s,
      rly_out3_3V_o     => rly_out3_3V_s, 
      spd_lim_st_o      => spd_lim_st_s                    --REQ: 192

   );
	
	clk_s <= not clk_s after 10 ns;
	
	stimulate: PROCESS
	BEGIN
		arst_s <= '1';
		
		spd_h25kmh_s <= '0';
      spd_h75kmh_s <= '0';
      spd_h90kmh_s <= '0';
      spd_h110kmh_s <= '0';
      spd_over_spd_s <= '0';
		
		zero_spd_s <= '0';
		
		mjr_flt_s <= '0';
		
		spd_lim_s <= '0';
	
		wait for 100 ns;
		
		arst_s <= '0';
				
		wait for 100 ns;
		
		spd_lim_s <= '1';
		
		wait for 100 us;
		
		zero_spd_s <= '1';
		
		wait for 50 us;
		
		zero_spd_s <= '0';
		
		wait for 50 us;
		
		spd_lim_s <= '0';
		
		wait for 100 us;
		
		zero_spd_s <= '0';
		
		wait for 100 us;
		
		spd_h25kmh_s <= '1';
		
		wait for 1000 us;
		
		spd_h25kmh_s <= '0';
      spd_h75kmh_s <= '0';
      spd_h90kmh_s <= '0';
      spd_h110kmh_s <= '0';
      spd_over_spd_s <= '0';
		
		zero_spd_s <= '0';
		
		mjr_flt_s <= '0';
		
		spd_lim_s <= '1';
		
		wait for 100 ns;
		
		spd_lim_s <= '0';
		
		wait for 100 us;
		
		zero_spd_s <= '1';
		
		wait for 100 us;
		
		zero_spd_s <= '0';
		
		wait for 100 us;
		
		spd_h25kmh_s <= '1';
		
		wait for 100 us;
		
		spd_h25kmh_s <= '0';
		zero_spd_s <= '0';
		spd_lim_s <= '1';
		
		wait for 50 us;
		
		zero_spd_s <= '1';
		
		wait for 50 us;
		
		spd_lim_s <= '0';
		
		wait for 100 us;
		
		zero_spd_s <= '1';
		
		wait for 100 us;
		
		zero_spd_s <= '0';
		
		wait for 100 us;
		
		spd_h25kmh_s <= '1';
		
		wait for 200 us;
		
		zero_spd_s <= '1';
		
		wait for 100 us;
		
		zero_spd_s <= '0';
		
		wait;

	END PROCESS stimulate;
	
	
END ARCHITECTURE beh;