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
  use uart_lib.receiver_utils.all;

-- Possible Bitrates which should be supported.
--   Bitrate   Duration
--     [s⁻¹]       [µs]

--        50  20.000,00
--       110   9.090,00
--       150   6.670,00
--       300   3.330,00
--     1.200     833,00
--     2.400     417,00
--     4.800     208,00
--     9.600     104,00
--    19.200      52,10
--    38.400      26,00
--    57.600      17,40
--   115.200       8,68
--   230.400       4,34
--   460.800       2,17
--   500.000       2,00


entity tb_transceiver is
  generic ( runner_cfg              : string
          ; encoded_parity          : string :=    "odd"
          ; encoded_ns_clock_period : string :=     "20"
          ; encoded_bits_per_second : string := "500000"
          ; encoded_data_bits       : string :=      "8"
         );
end entity tb_transceiver;


architecture bench of tb_transceiver is

  constant c_parity                           : t_parity                                     :=           decode_parity(encoded_parity);
  constant c_data_bits                        : positive                                     :=       positive'value(encoded_data_bits);
  constant c_ns_clock_period                  : positive                                     := positive'value(encoded_ns_clock_period);
  constant c_bits_per_second                  : positive                                     := positive'value(encoded_bits_per_second);
  constant c_duration                         : time                                         :=        (10**9/c_bits_per_second) * 1 ns;

  signal st_act                               : t_act                                        :=                                    idle;
  signal si_data, si_value                    : integer                                      :=                      2**c_data_bits - 1;
  signal s_rst, s_loop                        : std_ulogic                                   :=                                     '1';
  signal s_clk, s_ena, s_busy, s_par, s_valid : std_ulogic                                   :=                                     '0';
  signal sv_din, sv_dout                      : std_ulogic_vector (c_data_bits - 1 downto 0) :=                         (others => '0');

  shared variable rand_gen    : RandomPType;
begin
  -- Here we generate the System-Clock for this Test-Bench, guarded by another STOP-Condition.
  s_clk <= not s_clk after (c_ns_clock_period/2) * 1 ns;
  -- Here we schedule our testcases and let 'VUnit' manage them.
  main : process is
  begin
    -- We 'seed' our Random-Number-Generator, set up our test runner and configure our display handler.
    rand_gen.initseed(now/1 ns);
    test_runner_setup(runner, runner_cfg);
    show(get_logger(default_checker), display_handler, pass);

    if run("loopback") then
      do_rst(c_ns_clock_period, s_rst);
      wait for c_duration;
      wait until s_clk'event and s_clk = '1';
      s_ena <= '1';
      sv_din <= std_ulogic_vector(to_unsigned(42, 8));
      wait until s_clk'event and s_clk = '1';
      s_ena <= '0';
      sv_din <= std_ulogic_vector(to_unsigned(0, 8));
      wait until s_busy'event and s_busy = '0';
      wait for c_duration;

    end if;

    wait for (10*c_ns_clock_period/2) * 1 ns;
    test_runner_cleanup(runner);
    wait;
  end process main;

  test_runner_watchdog(runner, 200 ms);

  dut_transmitter : entity uart_lib.transmitter
  generic map (g_data_bits => c_data_bits, g_ns_clock_period => c_ns_clock_period, g_bits_per_second => c_bits_per_second, g_parity => c_parity)
  port map (clk => s_clk, rst => s_rst, ena => s_ena, din => sv_din, busy => s_busy, dout => s_loop);

  dut_receiver : entity uart_lib.receiver (dec)
    generic map (g_data_bits => c_data_bits, g_ns_clock_period => c_ns_clock_period, g_bits_per_second => c_bits_per_second, g_parity => c_parity)
    port map (clk => s_clk, rst => s_rst, din => s_loop, dout => sv_dout, par => s_par, valid => s_valid);
end bench;
