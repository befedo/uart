library ieee;
  use ieee.numeric_std.all;
  use ieee.std_logic_1164.all;

library vunit_lib;
  use vunit_lib.logger_pkg.all;
  context vunit_lib.vunit_context;
  context vunit_lib.vc_context;

library osvvm;
  use osvvm.RandomPkg.all;

library uart_lib;

entity tb_fifo is
  generic (runner_cfg: string);
end entity tb_fifo;

architecture bench of tb_fifo is
  constant c_width : positive := 8;
  constant c_length : positive := 4;
  constant c_ns_clock_period : positive := 20;

  signal s_rst : std_ulogic := '1';
  signal s_clk, s_we, s_re, s_empty, s_full, s_underflow, s_overflow : std_ulogic := '0';
  signal sv_data_in, sv_data_out : std_ulogic_vector (c_width - 1 downto 0) := (others => '0');

  signal si_rand : integer := 0;
  shared variable rand_gen    : RandomPType;

  procedure write_to_fifo ( signal clk : in std_ulogic
                          ; signal full : in std_ulogic
                          ; signal we : out std_ulogic
                          ; signal data : out std_ulogic_vector (c_width - 1 downto 0)
                          ) is
   variable rand : RandomPType;
  begin
    rand.initseed(now/1 ns);
    wait until clk'event and clk = '0';
    while not full loop
      data <= std_ulogic_vector(to_unsigned(rand.uniform(0, 2**c_width - 1), data'length));
      we <= '1';
      wait until clk'event and clk = '0';
    end loop;
    data <= (others => '0');
    we <= '0';
  end procedure write_to_fifo;

  procedure read_from_fifo ( signal clk : in std_ulogic
                           ; signal empty : in std_ulogic
                           ; signal re : out std_ulogic
                           ) is
  begin
    wait until clk'event and clk = '0';
    while not empty loop
      re <= '1';
      wait until clk'event and clk = '0';
    end loop;
    re <= '0';
  end procedure read_from_fifo;
begin

  s_clk <= not s_clk after (c_ns_clock_period/2) * 1 ns;

  process is
  begin
    -- We 'seed' our Random-Number-Generator, set up our test runner and configure our display handler.
    rand_gen.initseed(now/1 ns);
    test_runner_setup(runner, runner_cfg);
    show(get_logger(default_checker), display_handler, pass);

    wait for 25 ns;
    s_rst <= '0';
    wait for 30 ns;
    for i in 0 to 32 loop
      write_to_fifo(s_clk, s_full, s_we, sv_data_in);
      wait for 70 ns;
      read_from_fifo(s_clk, s_empty, s_re);
      wait for 70 ns;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process;

test_runner_watchdog(runner, 100 us);

dut : entity uart_lib.fifo (pow2)
        generic map (g_width => c_width, g_length => c_length)
        port map ( clk => s_clk, rst => s_rst, we_i => s_we, re_i => s_re, full_o => s_full
                 , empty_o => s_empty, underflow_o => s_underflow, overflow_o => s_overflow, data_i => sv_data_in, data_o => sv_data_out
                );

end bench;
