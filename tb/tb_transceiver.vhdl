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
          ; encoded_fifo_length     : string :=      "4" -- length will be 2**4
         );
end entity tb_transceiver;


architecture bench of tb_transceiver is

  constant c_parity                           : t_parity                                     :=           decode_parity(encoded_parity);
  constant c_data_bits                        : positive                                     :=       positive'value(encoded_data_bits);
  constant c_fifo_length                      : positive                                     :=     positive'value(encoded_fifo_length);
  constant c_ns_clock_period                  : positive                                     := positive'value(encoded_ns_clock_period);
  constant c_bits_per_second                  : positive                                     := positive'value(encoded_bits_per_second);
  constant c_duration                         : time                                         :=        (10**9/c_bits_per_second) * 1 ns;

  signal s_rst, s_loop                        : std_ulogic                                   :=                                     '1';
  signal s_clk, s_ena, s_busy, s_par, s_valid : std_ulogic                                   :=                                     '0';
  signal sv_din, sv_dout                      : std_ulogic_vector (c_data_bits - 1 downto 0) :=                         (others => '0');


  signal s_we_tx, s_full_tx                   : std_ulogic := '0';
  signal sv_data_in_tx                        : std_ulogic_vector (c_data_bits - 1 downto 0) := (others => '0');

  signal s_re_rx, s_full_rx                   : std_ulogic := '0';

  shared variable rand_gen                    : RandomPType;


  procedure write_to_fifo ( signal clk   : in  std_ulogic
                          ; signal full  : in  std_ulogic
                          ; signal we    : out std_ulogic
                          ; signal data  : out std_ulogic_vector (c_data_bits - 1 downto 0)
                          ; constant num : in  natural
                          ) is
    variable rand : RandomPType;
    variable count : natural range 0 to num := num;
  begin
    rand.initseed(now/1 ns);
    wait until clk'event and clk = '0';
    while full = '0' and (count > 0) loop
      data <= std_ulogic_vector(to_unsigned(rand.uniform(0, 2**c_data_bits - 1), data'length));
      we <= '1';
      count := count - 1;
      wait until clk'event and clk = '0';
    end loop;
    data <= (others => '0');
    we <= '0';
  end procedure write_to_fifo;
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
      -- wait until s_clk'event and s_clk = '1';
      -- s_ena <= '1';
      -- sv_din <= std_ulogic_vector(to_unsigned(42, 8));
      -- wait until s_clk'event and s_clk = '1';
      -- s_ena <= '0';
      -- sv_din <= std_ulogic_vector(to_unsigned(0, 8));
      -- wait until s_busy'event and s_busy = '0';
      -- wait for c_duration;

      write_to_fifo(s_clk, s_full_tx, s_we_tx, sv_data_in_tx, 15);
      wait until s_full_rx'event and s_full_rx = '1';
      wait for 25 us;
      -- wait;

    end if;

    wait for (10*c_ns_clock_period/2) * 1 ns;
    test_runner_cleanup(runner);
    wait;
  end process main;

  test_runner_watchdog(runner, 400 us);

  transmission : block is
    type   t_state is (idle, read_fifo, enable_transmitter);
    signal st_state, st_next_state : t_state;

    signal s_re_tx, s_empty_tx, s_overflow_tx, s_underflow_tx : std_ulogic := '0';
    signal sv_data_out_tx : std_ulogic_vector (c_data_bits - 1 downto 0) := (others => '0');
  begin
    states : process (s_clk, s_rst) is
    begin
      if s_rst then
        st_state <= idle;
      elsif s_clk'event and s_clk = '1' then
        st_state <= st_next_state;
      end if;
    end process states;

    transition : process (st_state, s_busy, s_empty_tx) is
    begin
      st_next_state <= idle;
      case st_state is
        when idle      => if not s_busy and not s_empty_tx then
                            st_next_state <= read_fifo;
                          end if;
        when read_fifo => st_next_state <= enable_transmitter;
        when others    => null;
      end case;
    end process transition;

    output : process (s_clk) is
    begin
      if s_clk'event and s_clk = '1' then
        s_re_tx <= '0'; s_ena <= '0';
        case st_next_state is
          when read_fifo          => s_re_tx <= '1';
          when enable_transmitter => s_ena <= '1';
          when others             => null;
        end case;
      end if;
    end process output;

    sv_din <= sv_data_out_tx;

    dut_transmitter : entity uart_lib.transmitter
    generic map (g_data_bits => c_data_bits, g_ns_clock_period => c_ns_clock_period, g_bits_per_second => c_bits_per_second, g_parity => c_parity)
    port map (clk_i => s_clk, rst_i => s_rst, ena_i => s_ena, data_i => sv_din, busy_o => s_busy, tx_o => s_loop);

    dut_tx_fifo : entity uart_lib.fifo (pow2)
    generic map (g_width => c_data_bits, g_length => c_fifo_length)
    port map ( clk => s_clk, rst => s_rst, we_i => s_we_tx, re_i => s_re_tx, full_o => s_full_tx, empty_o => s_empty_tx
             , underflow_o => s_underflow_tx, overflow_o => s_overflow_tx, data_i => sv_data_in_tx, data_o => sv_data_out_tx
             );
  end block transmission;

  reception : block
  is
    signal s_we_rx, s_empty_rx, s_overflow_rx, s_underflow_rx : std_ulogic := '0';
    signal sv_data_in_rx, sv_data_out_rx : std_ulogic_vector (c_data_bits - 1 downto 0) := (others => '0');
  begin
    s_we_rx       <= s_valid;
    sv_data_in_rx <= sv_dout;

    dut_receiver : entity uart_lib.receiver (dec)
    generic map (g_data_bits => c_data_bits, g_ns_clock_period => c_ns_clock_period, g_bits_per_second => c_bits_per_second, g_parity => c_parity)
    port map (clk_i => s_clk, rst_i => s_rst, rx_i => s_loop, data_o => sv_dout, par_o => s_par, valid_o => s_valid);

    dut_rx_fifo : entity uart_lib.fifo (pow2)
    generic map (g_width => c_data_bits, g_length => c_fifo_length)
    port map ( clk => s_clk, rst => s_rst, we_i => s_we_rx, re_i => s_re_rx, full_o => s_full_rx, empty_o => s_empty_rx
             , underflow_o => s_underflow_rx, overflow_o => s_overflow_rx, data_i => sv_data_in_rx, data_o => sv_data_out_rx
             );
  end block reception;
end bench;
