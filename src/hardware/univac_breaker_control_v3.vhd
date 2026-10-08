-- File Path: src/hardware/univac_breaker_control.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity univac_breaker_control is
    Generic (
        ---------------------------------------------------------------------
        -- UNIVAC HISTORICAL CURRENT SELECTION MATRIX (SSPC PRODUCTION RANGES)
        -- Scaled dynamically via 12-bit ADC threshold registers (0 to 4095 steps)
        ---------------------------------------------------------------------
        -- TIER 1: LIGHT DUTY INFRASTRUCTURE (15A - 30A Range)
        UNIVAC_RANGE_LIGHT_DUTY_ADC   : unsigned(11 downto 0) := to_unsigned(1228, 12); -- 15A Limit
        
        -- TIER 2: STANDARD UTILITY MOTOR DRIVES (35A - 60A Range)
        UNIVAC_RANGE_STANDARD_DRIVE_ADC: unsigned(11 downto 0) := to_unsigned(2457, 12); -- 35A Limit
        
        -- TIER 3: HEAVY INDUSTRIAL LOADS (70A - 100A Range)
        UNIVAC_RANGE_HEAVY_INDUSTRY_ADC: unsigned(11 downto 0) := to_unsigned(3276, 12); -- 70A Limit
        
        -- TIER 4: SUB-STATION GRID MAIN FEEDERS (125A - 200A Range)
        UNIVAC_RANGE_SUBSTATION_FEED_ADC: unsigned(11 downto 0) := to_unsigned(4095, 12); -- 125A Ceiling
        
        ---------------------------------------------------------------------
        -- UNIVAC HISTORICAL VOLTAGE COEFFICIENT SELECTION MATRIX
        -- Enforces native overvoltage spikes protection ceilings across all 5 configurations
        ---------------------------------------------------------------------
        -- VOLTAGE PROFILE 01: LOW-VOLTAGE AUTOMATION BUS (24V DC / 48V DC)
        -- Powering: Electronic magnetic door locks, sensor arrays, and Zephyr core microcontrollers
        UNIVAC_VOLT_DC_BUS_CEILING_V  : integer := 48;
        
        -- VOLTAGE PROFILE 02: UTILITY SPLIT-PHASE SYSTEM (120V / 240V AC Single-Phase)
        -- Powering: Automated facility door openers, garage gate winches, lighting, and tool room tools
        UNIVAC_VOLT_SINGLE_PHASE_MAX_V: integer := 240;
        
        -- VOLTAGE PROFILE 03: COMMERCIAL THREE-PHASE LOW-RAIL (208V / 240V AC Tri-Phase)
        -- Powering: Medium-capacity crop shakers, water sorting conveyor pumps, and auxiliary fans
        UNIVAC_VOLT_THREE_PHASE_LOW_V : integer := 240;
        
        -- VOLTAGE PROFILE 04: INDUSTRIAL THREE-PHASE HIGH-RAIL (480V AC Tri-Phase Delta/Wye)
        -- Powering: Heavy-duty 70A industrial food mixers, crop processors, and high-pressure water cannons
        UNIVAC_VOLT_THREE_PHASE_HIGH_V: integer := 480;
        
        -- VOLTAGE PROFILE 05: RENEWABLE SUB-STATION GRID TRANSLATION (690V AC Tri-Phase)
        -- Powering: Direct input injection from GE wind turbine generation and heavy load dump grids
        UNIVAC_VOLT_TURBINE_GRID_MAX_V: integer := 690
    );
    Port (
        -- High-Speed Timing & Control Interface Rails
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Synchronized to 10.0 MHz Industrial clock line
        SYSTEM_RESET           : in  STD_LOGIC;
        
        -- Digitized Load Current Sensors (12-bit Parallel Input Channels)
        SENSE_DOOR_OPENER_CURR : in  STD_LOGIC_VECTOR(11 downto 0);
        SENSE_GARAGE_GATE_CURR : in  STD_LOGIC_VECTOR(11 downto 0);
        SENSE_MIXER_MOTOR_CURR : in  STD_LOGIC_VECTOR(11 downto 0);
        SENSE_SOLENOID_LOCK_CURR: in  STD_LOGIC_VECTOR(11 downto 0);
        LOAD_SAMPLES_STROBE    : in  STD_LOGIC;
        
        -- Master Safety Override Inputs from the Private Server Bridges
        GLOBAL_PERIMETER_CLAMP : in  STD_LOGIC; -- Driven high instantly if a vehicle trespasses
        ANALOG_WINDOW_FAULT_IN : in  STD_LOGIC; -- Driven high if +/- 2mV lines slip out of spec
        
        -- Solid-State Output Gate Drivers Routed to Opto-Isolated Power Switches
        GATE_DRIVE_DOOR_OPENER : out STD_LOGIC; -- Held high to forward bias the solid-state gate
        GATE_DRIVE_GARAGE_GATE : out STD_LOGIC;
        GATE_DRIVE_MIXER_MOTOR : out STD_LOGIC;
        GATE_DRIVE_SOLENOID_LOCK: out STD_LOGIC;
        
        -- Native 16-State Master Safety Bus Link Indicator
        HEX_SAFETY_OUT         : out STD_LOGIC_VECTOR(3 downto 0)
    );
end univac_breaker_control;

architecture SolidStatePowerDistribution of univac_breaker_control is
    signal door_c, garage_c, mixer_c, lock_c : unsigned(11 downto 0);
begin
    door_c   <= unsigned(SENSE_DOOR_OPENER_CURR);
    garage_c <= unsigned(SENSE_GARAGE_GATE_CURR);
    mixer_c  <= unsigned(SENSE_MIXER_MOTOR_CURR);
    lock_c   <= unsigned(SENSE_SOLENOID_LOCK_CURR);

    process(CLK_INDUSTRIAL, SYSTEM_RESET)
        variable master_hardware_interlock : STD_LOGIC;
    begin
        if SYSTEM_RESET = '1' then
            GATE_DRIVE_DOOR_OPENER   <= '0'; -- Secure all solid-state outputs low on boot
            GATE_DRIVE_GARAGE_GATE   <= '0';
            GATE_DRIVE_MIXER_MOTOR   <= '0';
            GATE_DRIVE_SOLENOID_LOCK <= '0';
            HEX_SAFETY_OUT           <= "0000"; -- Safe state 0x0
        elsif rising_edge(CLK_INDUSTRIAL) then
            
            master_hardware_interlock := GLOBAL_PERIMETER_CLAMP or ANALOG_WINDOW_FAULT_IN;
            
            -----------------------------------------------------------------
            -- DIRECT HARDWARE OVERRIDE TRIPPING PIPELINE
            -----------------------------------------------------------------
            if master_hardware_interlock = '1' then
                GATE_DRIVE_DOOR_OPENER   <= '0';
                GATE_DRIVE_GARAGE_GATE   <= '0';
                GATE_DRIVE_MIXER_MOTOR   <= '0';
                GATE_DRIVE_SOLENOID_LOCK <= '0';
                HEX_SAFETY_OUT           <= "0000"; -- Force system down to state 0x0
                
            elsif LOAD_SAMPLES_STROBE = '1' then
                
                -- Circuit Breaker 1: Solenoid Safety Locks (TIER 1: 15A - 30A @ 24V/48V DC)
                if lock_c > UNIVAC_RANGE_LIGHT_DUTY_ADC then
                    GATE_DRIVE_SOLENOID_LOCK <= '0'; -- Fast solid-state breaker shutdown
                else
                    GATE_DRIVE_SOLENOID_LOCK <= '1'; -- Maintain active gate forward bias
                end if;
                
                -- Circuit Breaker 2: Automated Door Openers (TIER 2: 35A - 60A @ 120V/240V AC)
                if door_c > UNIVAC_RANGE_STANDARD_DRIVE_ADC then
                    GATE_DRIVE_DOOR_OPENER <= '0';
                else
                    GATE_DRIVE_DOOR_OPENER <= '1';
                end if;
                
                -- Circuit Breaker 3: High-Speed Garage Gates (TIER 2: 35A - 60A @ 120V/240V AC)
                if garage_c > UNIVAC_RANGE_STANDARD_DRIVE_ADC then
                    GATE_DRIVE_GARAGE_GATE <= '0';
                else
                    GATE_DRIVE_GARAGE_GATE <= '1';
                end if;
                
                -- Circuit Breaker 4: Heavy Industrial Mixers & Water Cannons (TIER 3: 70A - 100A @ 480V/690V AC)
                if mixer_c > UNIVAC_RANGE_HEAVY_INDUSTRY_ADC then
                    GATE_DRIVE_MIXER_MOTOR <= '0';
                else
                    GATE_DRIVE_MIXER_MOTOR <= '1';
                end if;
                
                HEX_SAFETY_OUT <= "1111"; -- Keep safety bus at maximum running capacity (0xF)
                
            end if;
        end if;
    end process;
end SolidStatePowerDistribution;
