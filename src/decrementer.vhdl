library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity decrementer is
  generic (
    g_length : positive := 8
  );
  port (
    clk  : in  std_ulogic;
    rst  : in  std_ulogic;
    ena  : in  std_ulogic;
    load : in  std_ulogic;
    din  : in  unsigned(g_length - 1 downto 0);
    dec  : out std_ulogic
  );
end entity decrementer;

architecture rtl of decrementer is
  signal s_dec  : std_ulogic;
  signal sv_din : unsigned(din'high + 1 downto din'low);
begin
  reg : process (clk, rst) is
  begin
    if rst = '1' then
      sv_din   <= (others => '0');
    elsif clk'event and clk = '1' then
      if load = '1' then
        sv_din <= '0' & din;
      elsif ena = '1' and s_dec = '1' then
        sv_din <= sv_din - 1;
      end if;
    end if;
  end process reg;
  --
  dec   <= not sv_din(sv_din'high);
  s_dec <= not sv_din(sv_din'high);
end rtl;
