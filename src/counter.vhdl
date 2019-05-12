library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.log2;
  use ieee.math_real.ceil;

library uart_lib;

entity counter is
  generic ( g_length : positive := 8
         );
  port ( clk  : in  std_ulogic
       ; rst  : in  std_ulogic
       ; ena  : in  std_ulogic
       ; clr  : in  std_ulogic
       ; dout : out unsigned (g_length - 1 downto 0)
      );
end entity counter;

architecture rtl of counter is
  signal value : unsigned (dout'range);
begin
  count: process (clk, ena, rst) is
  begin
    if (rst = '1') then
      value <= to_unsigned(0, value'length);
    elsif (clk'event and clk = '1') then
      if (clr = '1') then
        value <= to_unsigned(0, value'length);
      elsif (ena = '1') then
        value <= value + 1;
      end if;
    end if;
  end process count;
  --
  dout <= value;
end architecture rtl;

