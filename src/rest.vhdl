library ieee;
  use ieee.std_logic_1164.all;

library uart_lib;

entity rest is
  generic ( g_max_delay       : string := "400 ps"
          ; g_transport_delay : time   :=   10 ns
         );
  port ( clk     : in  std_ulogic
       ; ena     : in  std_ulogic
       ; rst     : in  std_ulogic
       ; clk_o   : out std_ulogic
       ; ena_o   : out std_ulogic
       ; rst_o   : out std_ulogic
       ; rst_n_o : out std_ulogic
      );
end entity rest;

architecture tran of rest is
  attribute maxdelay : string;
  signal s_rst_delayed, s_rst_comb, s_rst_t0, s_rst_t1 : std_ulogic;
  attribute maxdelay of s_rst_t0 : signal is g_max_delay;
begin
  -- We use a delayed signal strip and combine it with the original reset line (or'ed together).
  s_rst_delayed <= transport rst after g_transport_delay;
  -- s_rst_delayed <= rst'delayed(g_transport_delay);
  s_rst_comb <= rst or s_rst_delayed;
  -- Clock and enable signals where passed through.
  clk_o <= clk;
  ena_o <= ena;
  -- Here we generate the asynchronous reset and synchronous set, clocked through two FF's.
  gen_rst : process (clk, s_rst_comb) is
  begin
    if (s_rst_comb = '0') then
      s_rst_t0 <= '0';
      s_rst_t1 <= '0';
    elsif (clk'event and clk = '1') then
      s_rst_t0 <= '1';
      s_rst_t1 <= s_rst_t0;
    end if;
  end process gen_rst;
  -- Inverted and non-inverted output.
  rst_o <= not s_rst_t1;
  rst_n_o <= s_rst_t1;
end architecture tran;

