library ieee;
  use ieee.std_logic_1164.all;

library vunit_lib;
  context vunit_lib.vunit_context;

library uart_lib;

entity tb_rest is
  generic (runner_cfg : string);
end entity tb_rest;

architecture bench of tb_rest is
  signal clk, clk_o, ena, ena_o, rst, rst_o, rst_n_o, stp : std_ulogic;
begin
  -- Generate the clock signal, stop this when the testbench finishes.
  clk <= not clk after 20 us when stp = '0' else '0';
  -- Simple proces to generate the reset line and signal stop at the end.
  tests : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_checker_stat;
      if run("short_reset_glitch") then
        rst <= '0';
        ena <= '0';
        wait for 34 us;
        rst <= '1';
        wait for 42 us;
        ena <= '1';
        wait for 1234 us;
        rst <= '0';
        wait for 1 ns;
        rst <= '1';
        check_true(rst_o = '1', "Short reset glitch passed through.");
        wait for 1234 us;
        stp <= '1';
      elsif run("valid_reset_pulse") then
        rst <= '0';
        ena <= '0';
        wait for 34 us;
        rst <= '1';
        wait for 42 us;
        ena <= '1';
        wait for 1234 us;
        rst <= '0';
        wait for 20 ns;
        rst <= '1';
        check_true(rst_o = '1', "Reset not recognized.");
        wait for 1234 us;
        stp <= '1';
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process tests;

  dut : entity uart_lib.rest
    port map ( clk     => clk
             , ena     => ena
             , rst     => rst
             , clk_o   => clk_o
             , ena_o   => ena_o
             , rst_o   => rst_o
             , rst_n_o => rst_n_o
            );
end architecture bench;

