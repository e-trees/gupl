library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sendrecv_tb is
end entity sendrecv_tb;

architecture BEHAV of sendrecv_tb is
  
  component sendrecv
    port(
      -- input
      UPL_input_data : in std_logic_vector(128-1 downto 0);
      UPL_input_en : in std_logic;
      UPL_input_req : in std_logic;
      UPL_input_ack : out std_logic;
      
      -- output
      UPL_output_data : out std_logic_vector(128-1 downto 0);
      UPL_output_en : out std_logic;
      UPL_output_req : out std_logic;
      UPL_output_ack : in std_logic;
      
      -- system clock and reset
      clk : in std_logic;
      reset : in std_logic
      );
  end component sendrecv;

  signal UPL_input_data          : std_logic_vector(128-1 downto 0) := (others => '0');
  signal UPL_input_en            : std_logic := '0';
  signal UPL_input_req           : std_logic := '0';
  signal UPL_input_ack           : std_logic := '0';
  signal UPL_output_data         : std_logic_vector(128-1 downto 0) := (others => '0');
  signal UPL_output_en           : std_logic := '0';
  signal UPL_output_req          : std_logic := '0';
  signal UPL_output_ack          : std_logic := '0';
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
    
      case to_integer(counter) is
        when 1 =>
          reset <= '1';
        when 10 =>
          reset <= '0';
          UPL_output_ack <= '1';

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
      
  DUT : sendrecv
    port map(
      -- input
      UPL_input_data => UPL_input_data,
      UPL_input_en   => UPL_input_en,
      UPL_input_req  => UPL_input_req,
      UPL_input_ack  => UPL_input_ack,

      -- output
      UPL_output_data => UPL_output_data,
      UPL_output_en   => UPL_output_en,
      UPL_output_req  => UPL_output_req,
      UPL_output_ack  => UPL_output_ack,

      -- system clock and reset
      clk   => clk,
      reset => reset
      );
  
end BEHAV;
