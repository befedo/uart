library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library vunit_lib;
  context vunit_lib.vunit_context;

library uart_lib;

entity tb_decrementer is
  generic (runner_cfg : string);
end entity tb_decrementer;

architecture bench of tb_decrementer is
  signal clk, rst, ena, dec, load : std_ulogic := '0';
  signal din : unsigned (7 downto 0) := to_unsigned(16, 8);
begin
  --
  clk <= not clk after 20 us;
  --
  main : process
  begin
    test_runner_setup(runner, runner_cfg);
    --
    while test_suite loop
      reset_checker_stat;
      if run("default") then
        rst <= '1';
        load <= '0';
        wait for 100 us;
        rst <= '0';
        load <= '0';
        wait for 100 us;
        rst <= '0';
        load <= '1';
        wait until clk'event and clk = '0';
        load <= '0';
        wait for 45 us;
        ena <= '1';
        wait for 1000 us;
      end if;
    end loop;
    --
    test_runner_cleanup(runner);
    wait;
  end process main;
  --
  dut_decrementer : entity uart_lib.decrementer
    generic map ( g_length => 8 )
    port map ( clk  => clk
             , rst  => rst
             , ena  => ena
             , load => load
             , din  => din
             , dec  => dec
            );
end architecture bench;

