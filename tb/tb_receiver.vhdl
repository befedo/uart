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


entity tb_receiver is
  generic ( runner_cfg              : string
          ; encoded_parity          : string :=    "odd"
          ; encoded_ns_clock_period : string :=     "20"
          ; encoded_bits_per_second : string := "500000"
          ; encoded_data_bits       : string :=      "8"
         );
end entity tb_receiver;

architecture bench of tb_receiver is

  constant c_parity            : t_parity                                     :=           decode_parity(encoded_parity);
  constant c_data_bits         : positive                                     :=       positive'value(encoded_data_bits);
  constant c_ns_clock_period   : positive                                     := positive'value(encoded_ns_clock_period);
  constant c_bits_per_second   : positive                                     := positive'value(encoded_bits_per_second);
  constant c_duration          : time                                         :=        (10**9/c_bits_per_second) * 1 ns;

  signal st_act                : t_act                                        :=                                    idle;
  signal sb_enable_tx          : boolean                                      :=                                   false;
  signal si_data, si_value     : integer                                      :=                      2**c_data_bits - 1;
  signal s_rst, s_din          : std_ulogic                                   :=                                     '1';
  signal s_clk, s_valid, s_par : std_ulogic                                   :=                                     '0';
  signal sv_dout               : std_ulogic_vector (c_data_bits - 1 downto 0) :=                         (others => '0');

  shared variable rand_gen     : RandomPType;
begin
  -- Here we generate the System-Clock for this Test-Bench, guarded by another STOP-Condition.
  s_clk <= not s_clk after (c_ns_clock_period/2) * 1 ns;
  -- This is our concurent transmission procedure, it is called each time we write to it's inputs (like in the main process).
  -- Whilst using a guarded block statement, provides control over the initial behaviour.
  block_tx : block (sb_enable_tx = true) is
  begin
    do_tx(si_value, c_duration, c_data_bits, c_parity, s_din, st_act, si_data);
  end block block_tx;
  -- Here we schedule our testcases and let 'VUnit' manage them.
  main : process is
  begin
    -- We 'seed' our Random-Number-Generator, set up our test runner and configure our display handler.
    rand_gen.initseed(now/1 ns);
    test_runner_setup(runner, runner_cfg);
    show(get_logger(default_checker), display_handler, pass);
    -- Enable Transmission block.
    sb_enable_tx <= true;

    if run("check.valid.on.start") then
      do_rst(c_ns_clock_period, s_rst);
      wait until s_valid'event for 20 * c_ns_clock_period * 1 ns;
      check(s_valid = '0', "Sanity check for 'valid' on startup.");
    elsif run("check.par.on.start") then
      do_rst(c_ns_clock_period, s_rst);
      wait until s_par'event for 20 * c_ns_clock_period * 1 ns;
      check(s_par = '0' or s_par = '-', "Sanity check for 'par' on startup.");
    elsif run("check.dout.on.start") then
      do_rst(c_ns_clock_period, s_rst);
      wait until sv_dout'event for 20 * c_ns_clock_period * 1 ns;
      check_equal(sv_dout, 0, "Sanity check for 'dout' on startup.");
    elsif run("transfer.single") then
      do_rst(c_ns_clock_period, s_rst);
      wait until s_valid'event and s_valid = '1';
      check_equal(sv_dout, si_data, "Compairing sent and received data.");
      check(s_par /= '1', "Parity check for '" & to_string(si_data) & "'.");
      wait for c_duration;
    elsif run("transfer.multi") then
      do_rst(c_ns_clock_period, s_rst);
      for i in 1 to 2**(c_data_bits - 1) loop
        si_value <= rand_gen.uniform(0, 2**c_data_bits - 1);
        wait until s_valid'event and s_valid = '1';
        check_equal(sv_dout, si_data, "Compairing sent and received data.");
        check(s_par /= '1', "Parity check for '" & to_string(si_data) & "'.");
        -- TODO: Make this period random.
        wait for c_duration;
      end loop;
    end if;

    wait for (10*c_ns_clock_period/2) * 1 ns;
    test_runner_cleanup(runner);
    wait;
  end process main;

  test_runner_watchdog(runner, 200 ms);

  dut : entity uart_lib.receiver (dec)
    generic map (g_data_bits => c_data_bits, g_ns_clock_period => c_ns_clock_period, g_bits_per_second => c_bits_per_second, g_parity => c_parity)
    port map (clk => s_clk, rst => s_rst, din => s_din, dout => sv_dout, par => s_par, valid => s_valid);
end bench;

