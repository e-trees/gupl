library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity command_parser_tb is
end entity command_parser_tb;

architecture BEHAV of command_parser_tb is
  
  component command_parser
    port(
      -- input
      UPL_input_data : in std_logic_vector(128-1 downto 0);
      UPL_input_en : in std_logic;
      UPL_input_req : in std_logic;
      UPL_input_ack : out std_logic;
      
      -- forward_input
      UPL_forward_input_data : in std_logic_vector(128-1 downto 0);
      UPL_forward_input_en : in std_logic;
      UPL_forward_input_req : in std_logic;
      UPL_forward_input_ack : out std_logic;
      
      -- output
      UPL_output_data : out std_logic_vector(128-1 downto 0);
      UPL_output_en : out std_logic;
      UPL_output_req : out std_logic;
      UPL_output_ack : in std_logic;
      
      -- forward_output
      UPL_forward_output_data : out std_logic_vector(128-1 downto 0);
      UPL_forward_output_en : out std_logic;
      UPL_forward_output_req : out std_logic;
      UPL_forward_output_ack : in std_logic;
      
      -- user-defiend ports
      synch_sender_kick : out std_logic;
      synch_sender_busy : in std_logic;
      synch_target_addr : out std_logic_vector(32-1 downto 0);
      global_clock : in std_logic_vector(64-1 downto 0);
      global_clock_clear : out std_logic;
      
      -- system clock and reset
      clk : in std_logic;
      reset : in std_logic
      );
  end component command_parser;

  signal UPL_input_data          : std_logic_vector(128-1 downto 0) := (others => '0');
  signal UPL_input_en            : std_logic := '0';
  signal UPL_input_req           : std_logic := '0';
  signal UPL_input_ack           : std_logic := '0';
  signal UPL_forward_input_data  : std_logic_vector(128-1 downto 0) := (others => '0');
  signal UPL_forward_input_en    : std_logic := '0';
  signal UPL_forward_input_req   : std_logic := '0';
  signal UPL_forward_input_ack   : std_logic := '0';
  signal UPL_output_data         : std_logic_vector(128-1 downto 0) := (others => '0');
  signal UPL_output_en           : std_logic := '0';
  signal UPL_output_req          : std_logic := '0';
  signal UPL_output_ack          : std_logic := '0';
  signal UPL_forward_output_data : std_logic_vector(128-1 downto 0) := (others => '0');
  signal UPL_forward_output_en   : std_logic := '0';
  signal UPL_forward_output_req  : std_logic := '0';
  signal UPL_forward_output_ack  : std_logic := '0';
  signal synch_sender_kick       : std_logic;
  signal synch_sender_busy       : std_logic := '0';
  signal synch_target_addr       : std_logic_vector(32-1 downto 0) := (others => '0');
  signal global_clock            : std_logic_vector(64-1 downto 0) := (others => '0');
  signal global_clock_clear      : std_logic;
  signal clk                     : std_logic := '0';
  signal reset                   : std_logic := '0';

  signal counter : unsigned(31 downto 0) := (others => '0');
  
begin

  process
  begin
    clk <= not clk;
    wait for 5ns;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      counter <= counter + 1;
      
      if global_clock_clear = '1' then
        global_clock <= (others => '0');
      else
        global_clock <= std_logic_vector(unsigned(global_clock) + 1);
      end if;
    
      case to_integer(counter) is
        when 1 =>
          reset <= '1';
        when 10 =>
          reset <= '0';
          UPL_output_ack <= '1';
          UPL_forward_output_ack <= '1';

        when 100 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"0a000001" & X"0a000003" & X"40004001" & X"00000008";
        when 101 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"34000000" & X"00000000" & X"00000000" & X"00000000";
        when 102 =>
          UPL_input_en <= '0';

        when 200 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"0a000001" & X"0a000003" & X"40004001" & std_logic_vector(to_unsigned(64, 32));
        when 201 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"32000000" & X"00000000" & X"0a020001" & X"00004000";
        when 202 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"0a020002" & X"00004001" & X"0a020003" & X"00004002";
        when 203 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"0a020004" & X"00004003" & X"0a020005" & X"00004004";
        when 204 =>
          UPL_input_en <= '1';
          UPL_input_data <= X"0a020006" & X"00004005" & X"0a020007" & X"00004006";
        when 205 =>
          UPL_input_en <= '0';

        when others => null;
      end case;
    end if;
  end process;
      
  DUT : command_parser
    port map(
      -- input
      UPL_input_data => UPL_input_data,
      UPL_input_en   => UPL_input_en,
      UPL_input_req  => UPL_input_req,
      UPL_input_ack  => UPL_input_ack,

      -- forward_input
      UPL_forward_input_data => UPL_forward_input_data,
      UPL_forward_input_en   => UPL_forward_input_en,
      UPL_forward_input_req  => UPL_forward_input_req,
      UPL_forward_input_ack  => UPL_forward_input_ack,

      -- output
      UPL_output_data => UPL_output_data,
      UPL_output_en   => UPL_output_en,
      UPL_output_req  => UPL_output_req,
      UPL_output_ack  => UPL_output_ack,

      -- forward_output
      UPL_forward_output_data => UPL_forward_output_data,
      UPL_forward_output_en   => UPL_forward_output_en,
      UPL_forward_output_req  => UPL_forward_output_req,
      UPL_forward_output_ack  => UPL_forward_output_ack,

      -- user-defiend ports
      synch_sender_kick  => synch_sender_kick,
      synch_sender_busy  => synch_sender_busy,
      synch_target_addr  => synch_target_addr,
      global_clock       => global_clock,
      global_clock_clear => global_clock_clear,

      -- system clock and reset
      clk   => clk,
      reset => reset
      );
  
end BEHAV;
