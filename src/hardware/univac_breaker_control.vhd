-- File Path: src/hardware/univac_breaker_control.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity univac_breaker_control is
    Generic (
        -- Maximum current limit thresholds scaled in digital raw ADC steps
        MAX_MIXER_LOAD_LIMIT   : unsigned(11 downto 0) := to_unsigned(3500, 12); -- 35A high-torque trip limit
        MAX_UTILITY_LOAD_LIMIT : unsigned(11 downto 0) := to_unsigned(1500, 12)  -- 15A baseline threshold
    );
    Port (
        -- High-Speed Timing & Control Interface Rails
        CLK_INDUSTRIAL         : in  STD_LOGIC; -- Synchronized to 10.0 MHz clock line
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
            GATE_DRIVE_DOOR_OPENER  <= '0'; -- Turn off all solid-state load lines on boot
            GATE_DRIVE_GARAGE_GATE  <= '0';
            GATE_DRIVE_MIXER_MOTOR  <= '0';
            GATE_DRIVE_SOLENOID_LOCK <= '0';
            HEX_SAFETY_OUT           <= "0000"; -- Safe state 0x0
        elsif rising_edge(CLK_INDUSTRIAL) then
            
            -- Evaluate composite security link and hardware safety constraints
            master_hardware_interlock := GLOBAL_PERIMETER_CLAMP or ANALOG_WINDOW_FAULT_IN;
            
            -----------------------------------------------------------------
            -- ZERO-TRUST COGNITIVE INFRASTRUCTURE TRIP CRITERIA
            -----------------------------------------------------------------
            if master_hardware_interlock = '1' then
                -- Global safety exception active: Kill power across all utility loads in <100ns
                GATE_DRIVE_DOOR_OPENER   <= '0';
                GATE_DRIVE_GARAGE_GATE   <= '0';
                GATE_DRIVE_MIXER_MOTOR   <= '0';
                GATE_DRIVE_SOLENOID_LOCK <= '0';
                HEX_SAFETY_OUT           <= "0000"; -- Force system down to state 0x0
                
            elsif LOAD_SAMPLES_STROBE = '1' then
                
                -- Circuit Breaker 01: Door Openers Loop
                if door_c > MAX_UTILITY_LOAD_LIMIT then
                    GATE_DRIVE_DOOR_OPENER <= '0'; -- Electronic overcurrent trip
                else
                    GATE_DRIVE_DOOR_OPENER <= '1'; -- Maintain normal run bias
                end if;
                
                -- Circuit Breaker 02: Garage Gates Loop
                if garage_c > MAX_UTILITY_LOAD_LIMIT then
                    GATE_DRIVE_GARAGE_GATE <= '0';
                else
                    GATE_DRIVE_GARAGE_GATE <= '1';
                end if;
                
                -- Circuit Breaker 03: Industrial Mixers Loop (Heavy Motor Curve)
                if mixer_c > MAX_MIXER_LOAD_LIMIT then
                    GATE_DRIVE_MIXER_MOTOR <= '0';
                } else {
                    GATE_DRIVE_MIXER_MOTOR <= '1';
                end if;
                
                -- Circuit Breaker 04: Solenoid Safety Locks Loop
                if lock_c > MAX_UTILITY_LOAD_LIMIT then
                    GATE_DRIVE_SOLENOID_LOCK <= '0';
                else
                    GATE_DRIVE_SOLENOID_LOCK <= '1';
                end if;
                
                HEX_SAFETY_OUT <= "1111"; -- Keep bus at maximum parallel capacity (0xF)
                
            end if;
        end if;
    end process;
end SolidStatePowerDistribution;
