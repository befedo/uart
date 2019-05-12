library ieee;
  use ieee.std_logic_1164.all;

library uart_lib;
  use uart_lib.receiver_utils.all;


entity uart is
  generic (
    g_data_bits       : positive :=      8;
    g_ns_clock_period : positive :=     10;
    g_bits_per_second : positive := 115200;
    g_parity          : t_parity :=    odd
  );
  port (
    clk   : in  std_ulogic;
    rst   : in  std_ulogic;
    rx    : in  std_ulogic;
    dout  : out std_ulogic_vector (g_data_bits - 1 downto 0);
    par   : out std_ulogic;
    valid : out std_ulogic
  );
end entity uart;


architecture rtl of uart is
  signal s_par, s_valid : std_ulogic;
  signal sv_dout        : std_ulogic_vector (dout'range);
begin
  reg_out : process (clk, rst) is
  begin
    if rst = '1' then
      par <= '0';
      valid <= '0';
      dout <= (others => '0');
    elsif clk'event and clk = '1' then
      par <= s_par;
      valid <= s_valid;
      dout <= sv_dout;
    end if;
  end process reg_out;

  receiver : entity uart_lib.receiver (dec)
    generic map ( g_data_bits       => g_data_bits
                , g_ns_clock_period => g_ns_clock_period
                , g_bits_per_second => g_bits_per_second
                , g_parity          => g_parity
                )
    port map ( clk   => clk
             , rst   => rst
             , din   => rx
             , dout  => sv_dout
             , par   => s_par
             , valid => s_valid
            );
end rtl;
