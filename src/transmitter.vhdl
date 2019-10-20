library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use ieee.math_real.log2;
  use ieee.math_real.ceil;

library uart_lib;
  use uart_lib.receiver_utils.all;


entity transmitter is
  generic ( g_data_bits       : positive :=      8
          ; g_ns_clock_period : positive :=     20
          ; g_bits_per_second : positive := 500000
          ; g_parity          : t_parity :=   even
         );
  port ( clk  : in  std_ulogic
       ; rst  : in  std_ulogic
       ; ena  : in  std_ulogic
       ; din  : in  std_ulogic_vector (g_data_bits - 1 downto 0)
       ; busy : out std_ulogic
       ; dout : out std_ulogic
      );
end entity transmitter;


architecture rtl of transmitter is
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

  type   t_state is (idle, start, sleep, write, stop);
  signal st_state, st_next_state : t_state;

  signal sv_din, sv_din_t : std_ulogic_vector (c_data_length - 1 downto 0);
  -- Signals for the Decimators.
  signal s_enable_write, s_load_write, s_write : std_ulogic;
  signal s_enable_baud, s_load_baud, s_baud    : std_ulogic;
  signal sv_din_baud                           : unsigned (integer(ceil(log2(real(c_baud_length + 1)))) - 1 downto 0);
  signal sv_din_write                          : unsigned (integer(ceil(log2(real(c_data_length + 1)))) - 1 downto 0);
begin

  gen_parity : case g_parity generate
    when odd    => sv_din <= din & not (xor din);
    when even   => sv_din <= din & xor din;
    when others => sv_din <= din;
  end generate gen_parity;

  -- State-Machine ... TODO: Add description. {{{
  states : process (clk, rst) is
  begin
    if rst then
      st_state <= idle;
    elsif clk'event and clk = '1' then
      st_state <= st_next_state;
    end if;
  end process states;

  transition : process (ena, s_baud, s_write, st_state) is
  begin
    st_next_state <= idle;

    case st_state is
      when idle      => if ena then
                          st_next_state <= start;
                        end if;

      when start     => if s_baud then
                          st_next_state <= start;
                        else
                          st_next_state <= write;
                        end if;

      when sleep     => if s_baud then
                          st_next_state <= sleep;
                        else
                          st_next_state <= write;
                        end if;

      when write     => if s_write then
                          st_next_state <= sleep;
                        else
                          st_next_state <= stop;
                        end if;

      when stop      => if s_baud then
                          st_next_state <= stop;
                        end if;
      when others    => null;
    end case;
  end process transition;

  output : process (clk) is
  begin
    if clk'event and clk = '1' then
      -- Default assignments for all used counters.
      s_enable_baud <= '0'; s_load_baud <= '0'; sv_din_baud <= (others => '0');
      s_enable_write <= '0'; s_load_write <= '0'; sv_din_write <= (others => '0');
      -- Default assignments for all given registers and outputs.
      busy <= '1'; sv_din_t <= sv_din_t; dout <= sv_din_t(sv_din_t'high);

      case st_next_state is
        when idle   => dout <= '1';
                       busy <= '0';

        when start  => dout <= '0';
                       if st_state = start then
                         s_enable_baud <= '1';
                         s_load_write  <= '1';
                         sv_din_write  <= to_unsigned(c_data_length - 1, sv_din_write'length);
                       elsif st_state = idle then
                         sv_din_t      <= sv_din;
                         s_load_baud   <= '1';
                         sv_din_baud   <= to_unsigned(c_baud_length - 3, sv_din_baud'length);
                       end if;

        when sleep  => s_enable_baud <= '1';

        when write  => s_enable_write <= '1';
                       if st_state = start or st_state = sleep then
                         if st_state = sleep then
                           sv_din_t <= sv_din_t sll 1;
                         end if;
                         s_load_baud   <= '1';
                         sv_din_baud   <= to_unsigned(c_baud_length - 3, sv_din_baud'length);
                       end if;

        when stop   => dout <= '1';
                       s_enable_baud <= '1';

        when others => null;

      end case;
    end if;
  end process output;
  -- }}}

  -- Those 'Counters' build the Time-Base for our State-Machine. {{{
  baud_decrementer : entity uart_lib.decrementer
    generic map (g_length => sv_din_baud'length)
    port map (clk => clk, rst => rst, ena => s_enable_baud, load => s_load_baud, din => sv_din_baud, dec => s_baud);

  write_decrementer : entity uart_lib.decrementer
    generic map (g_length => sv_din_write'length)
    port map (clk => clk, rst => rst, ena => s_enable_write, load => s_load_write, din => sv_din_write, dec => s_write);
  -- }}}

end architecture rtl;

-- vim : foldmethod = marker

