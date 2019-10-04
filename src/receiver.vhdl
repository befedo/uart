library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.log2;
  use ieee.math_real.ceil;


library uart_lib;
  use uart_lib.receiver_utils.all;


entity receiver is
  generic ( g_data_bits       : positive :=      8
          ; g_ns_clock_period : positive :=     20
          ; g_bits_per_second : positive := 500000
          ; g_parity          : t_parity :=   even
         );
  port ( clk   : in  std_ulogic
       ; rst   : in  std_ulogic
       ; din   : in  std_ulogic
       ; par   : out std_ulogic
       ; valid : out std_ulogic
       ; dout  : out std_ulogic_vector (g_data_bits - 1 downto 0)
      );
end entity receiver;


architecture dec of receiver is
  function get_data_length (constant bits : in positive; constant parity : in t_parity) return positive is
  begin
    case parity is
      when none   => return bits;
      when others => return bits + 1;
    end case;
  end function get_data_length;
  -- Constants for our decimators.
  constant c_data_length  : positive := get_data_length(g_data_bits, g_parity);
  constant c_baud_length  : positive := 10**9 / (g_ns_clock_period * g_bits_per_second);
  constant c_start_length : positive := 15*10**8 / (g_ns_clock_period * g_bits_per_second);
  -- States for our State-Machine.
  type   t_state is (idle, start, sleep, read, check_stop, stop);
  signal st_state, st_next_state : t_state;
  -- Parity and Start signals, used by the State-Machine.
  signal s_par, s_start                     : std_ulogic;
  -- Signals for the Decimators.
  signal s_enable_read, s_load_read, s_read : std_ulogic;
  signal s_enable_baud, s_load_baud, s_baud : std_ulogic;
  signal sv_din_baud                        : unsigned (integer(ceil(log2(real(c_start_length + 1)))) - 1 downto 0);
  signal sv_din_read                        : unsigned (integer(ceil(log2(real(c_data_length + 1)))) - 1 downto 0);
  -- IN/OUT-Registers.
  signal sv_din                             : std_ulogic_vector (2 downto 0);
  signal sv_dout                            : std_ulogic_vector (c_data_length downto 0);
begin
  -- Assert-Statements {{{
    -- Through State-Transitions we loose 4 clock cycles per bit, which means the bit must be at lest 4*clk period.
    assert   c_baud_length >= 4
    report   "Baud length is to short for state counter."
    severity Error;
  -- }}}

  -- This is a three Process Description of our State-Machine, which is controled by the three counters 'below'. {{{
  states : process (clk, rst) is
  begin
    if rst = '1' then
      st_state <= idle;
      s_start  <= '0';
      sv_din   <= (others => '1'); -- When the bus is inactive TX remains '1', thus we initialize our input registers with '1'.
    elsif clk'event and clk = '1' then
      st_state <= st_next_state;
      s_start  <= sv_din(sv_din'left) and not sv_din(sv_din'left - 1);
      sv_din   <= sv_din(sv_din'left - 1 downto sv_din'right) & din;
    end if;
  end process states;

  transition : process (s_start, s_read, s_baud, st_state, sv_dout) is
  begin
    st_next_state <= idle;

    case st_state is
      when idle       => if s_start = '1' then
                           st_next_state <= start;
                         end if;

      when start      => if s_baud = '1' then
                           st_next_state <= start;
                         else
                           st_next_state <= read;
                         end if;

      when sleep      => if s_baud = '1' then
                           st_next_state <= sleep;
                         else
                           st_next_state <= read;
                         end if;

      when read       => if s_read = '1' then
                          st_next_state <= sleep;
                         else
                           st_next_state <= check_stop;
                         end if;

      when check_stop => if sv_dout(sv_dout'right) = '1' then
                           st_next_state <= stop;
                         end if;

      when others     => null;

    end case;
  end process transition;

  output : process (clk, rst) is
  begin
    if rst = '1' then
      -- Default assignments for all used counters.
      s_enable_read <= '0'; s_load_read <= '0'; sv_din_read <= (others => '0');
      s_enable_baud <= '0'; s_load_baud <= '0'; sv_din_baud <= (others => '0');
      -- Default assignments for the controll path output.
      valid <= '0';
    elsif clk'event and clk = '1' then
      -- Default assignments for all used counters.
      s_enable_read <= '0'; s_load_read <= '0'; sv_din_read <= (others => '0');
      s_enable_baud <= '0'; s_load_baud <= '0'; sv_din_baud <= (others => '0');
      -- Default assignments for all given outputs.
      par   <= '0';
      valid <= '0';
      dout  <= (others => '0');

      case st_next_state is
        when start     => if st_state = start then
                            s_enable_baud <= '1';
                            s_load_read   <= '1';
                            sv_din_read   <= to_unsigned(c_data_length - 1, sv_din_read'length);
                          elsif st_state = idle then
                            s_load_baud   <= '1';
                            sv_din_baud   <= to_unsigned(c_start_length - 3, sv_din_baud'length);
                          end if;

        when sleep     => s_enable_baud <= '1';

        when read      => s_enable_read <= '1';
                          if st_state = start or st_state = sleep then
                            -- s_load_read   <= '1';
                            s_load_baud   <= '1';
                            -- sv_din_read   <= to_unsigned(c_data_length - 1, sv_din_read'length);
                            sv_din_baud   <= to_unsigned(c_baud_length - 3, sv_din_baud'length);
                          end if;

        -- NOTE: 's_par' and 'sv_dout' are registered signals, so we don't need a new state depending on them.
        when stop      => par   <= s_par;
                          valid <= '1';
                          gen_dout : case g_parity is
                            when none   => dout <= sv_dout(sv_dout'left downto sv_dout'right + 1);
                            when others => dout <= sv_dout(sv_dout'left downto sv_dout'right + 2);
                          end case gen_dout;

        when others    => null;

      end case;
    end if;
  end process output;
  -- }}}

  -- Here we drive our internal Shift-Register depending on the State of the State-Machine. {{{
  shift_input : process (clk, rst) is
  begin
    if rst = '1' then
      sv_dout <= (others => '0');
    elsif clk'event and clk = '1' then
      if st_state = read then
        sv_dout <= sv_dout(sv_dout'left - 1 downto sv_dout'right) & sv_din(sv_din'left);
      elsif st_state = idle then
        sv_dout <= (others => '0');
      end if;
    end if;
  end process shift_input;
  -- }}}

  -- Concurent Assignments depending on the Generic Configuration of this Unit. {{{
  gen_parity : case g_parity generate
    when odd    => s_par <= not (xor sv_dout(sv_dout'left downto sv_dout'right + 1));
    when even   => s_par <= xor sv_dout(sv_dout'left downto sv_dout'right + 1);
    when others => s_par <= '-';
  end generate gen_parity;
  -- }}}

  -- Those 'Counters' build the Time-Base for our State-Machine. {{{
  baud_decrementer : entity uart_lib.decrementer
    generic map (g_length => sv_din_baud'length)
    port map (clk => clk, rst => rst, ena => s_enable_baud, load => s_load_baud, din => sv_din_baud, dec => s_baud);

  read_decrementer : entity uart_lib.decrementer
    generic map (g_length => sv_din_read'length)
    port map (clk => clk, rst => rst, ena => s_enable_read, load => s_load_read, din => sv_din_read, dec => s_read);
  -- }}}

end architecture dec;

-- vim : foldmethod = marker

