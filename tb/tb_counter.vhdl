library ieee;
  use ieee.std_logic_1164.all;

library vunit_lib;
  context vunit_lib.vunit_context;

library uart_lib;

entity tb_counter is
  generic (runner_cfg : string);
end entity tb_counter;

architecture bench of tb_counter is
  signal clk, clk_o, ena, ena_o, clr_o, rst, rst_o, stp : std_ulogic;
begin

  clk <= not clk after 20 us when stp = '0' else '0';

  main : process
  begin
    test_runner_setup(runner, runner_cfg);

    while test_suite loop
      reset_checker_stat;
      if run("default") then
        rst <= '0';
        ena <= '0';
        wait for 34 us;
        rst <= '1';
        wait for 42 us;
        ena <= '1';
        wait for 255 us;
        ena <= '0';
        wait for 50 us;
        ena <= '1';
        wait for 1234 us;
        clr_o <= '1';
        wait for 30 us;
        clr_o <= '0';
        wait for 1234 us;
        rst <= '0';
        wait for 1 ns;
        rst <= '1';
        wait for 1337 us;
        rst <= '0';
        wait for 20 ns;
        rst <= '1';
        wait for 1 ms;
        stp <= '1';
      end if;
    end loop;

    test_runner_cleanup(runner);
    wait;
  end process main;

  dut_rest : entity uart_lib.rest
    port map ( clk     => clk
             , ena     => ena
             , rst     => rst
             , clk_o   => clk_o
             , ena_o   => ena_o
             , rst_o   => rst_o
             , rst_n_o => open
            );

  dut_counter : entity uart_lib.counter
    generic map ( g_length => 8 )
    port map ( clk  => clk_o
             , rst  => rst_o
             , ena  => ena_o
             , clr  => clr_o
             , dout => open
            );
end architecture bench;

