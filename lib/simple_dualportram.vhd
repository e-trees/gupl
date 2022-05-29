library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity simple_dualportram is
  
  generic (
    DEPTH : integer := 10;
    WIDTH : integer := 32;
    WORDS : integer := 1024
  );

  port (
    clk    : in  std_logic;
    reset  : in  std_logic;
    we     : in  std_logic_vector(0 downto 0);
    raddr  : in  std_logic_vector(31 downto 0);
    waddr  : in  std_logic_vector(31 downto 0);
    dout   : out std_logic_vector(WIDTH-1 downto 0);
    din    : in  std_logic_vector(WIDTH-1 downto 0);
    length : out std_logic_vector(31 downto 0)
    );

end simple_dualportram;

architecture RTL of simple_dualportram is

  type ram_type is array (WORDS-1 downto 0) of std_logic_vector (WIDTH-1 downto 0);
  signal RAM: ram_type := (others => (others => '0'));

  attribute ram_style : string;
  attribute ram_style of RAM : signal is "block";

  signal q : std_logic_vector(WIDTH-1 downto 0) := (others => '0');

begin  -- RTL

  length <= std_logic_vector(to_signed(WORDS, length'length));
  dout <= q;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      if we(0) = '1' then
        RAM(to_integer(unsigned(waddr(DEPTH-1 downto 0)))) <= din;
      end if;
    end if;
  end process;

  process (clk)
  begin  -- process
    if rising_edge(clk) then
      q <= RAM(to_integer(unsigned(raddr(DEPTH-1 downto 0))));
    end if;
  end process;

end RTL;
