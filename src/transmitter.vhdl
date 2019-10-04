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
  -- function get_data_length (constant bits : in positive; constant parity : in t_parity) return positive is
  -- begin
  --   case parity is
  --     when none   => return bits;
  --     when others => return bits + 1;
  --   end case;
  -- end function get_data_length;
  --
  -- constant c_data_length  : positive := get_data_length(g_data_bits, g_parity);
  -- constant c_baud_length  : positive := 10**9 / (g_ns_clock_period * g_bits_per_second);
  --
  -- type   t_state is (idle, start, clr_start, sleep, clr_sleep, write, clr_write, stop, clr_stop);
  -- signal st_state, st_next_state : t_state;
  --
  -- signal sv_din, sv_din_t : std_ulogic_vector (c_data_length - 1 downto 0);
  -- signal s_enable_write_counter, s_clr_write_counter : std_ulogic;
  -- signal s_enable_baud_counter, s_clr_baud_counter   : std_ulogic;
  -- signal sv_dout_baud_counter                        : unsigned (integer(ceil(log2(real(c_baud_length + 1)))) - 1 downto 0);
  -- signal sv_dout_write_counter                       : unsigned (integer(ceil(log2(real(c_data_length + 1)))) - 1 downto 0);
begin
  --
  -- -- State-Machine ... TODO: Add description. {{{
  -- states : process (clk, rst) is
  -- begin
  --   if rst = '1' then
  --     st_state <= idle;
  --   elsif clk'event and clk = '1' then
  --     st_state <= st_next_state;
  --   end if;
  -- end process states;
  --
  -- transition : process (ena, din, st_state, sv_dout_baud_counter, sv_dout_write_counter) is
  -- begin
  --   st_next_state <= idle;
  --
  --   case st_state is
  --     when idle      => if ena = '1' then
  --                         st_next_state <= start;
  --                       end if;
  --     -- NOTE: Whe compare to 'c_start_length - 3' to incorporate our needed clock pulses for the state transition.
  --     when start     => if sv_dout_baud_counter >= to_unsigned(c_baud_length - 3, sv_dout_baud_counter'length) then
  --                         st_next_state <= clr_start;
  --                       else
  --                         st_next_state <= start;
  --                       end if;
  --
  --     when clr_start => st_next_state <= write;
  --
  --     -- NOTE: Whe compare to 'c_baud_length - 3' to incorporate our needed clock pulses for the state transition.
  --     when sleep     => if sv_dout_baud_counter >= to_unsigned(c_baud_length - 3, sv_dout_baud_counter'length) then
  --                         st_next_state <= clr_sleep;
  --                       else
  --                         st_next_state <= sleep;
  --                       end if;
  --
  --     when clr_sleep => st_next_state <= write;
  --
  --     when write     => if sv_dout_write_counter >= to_unsigned(c_data_length, sv_dout_write_counter'length) then
  --                         st_next_state <= clr_write;
  --                       else
  --                         st_next_state <= sleep;
  --                       end if;
  --
  --     when clr_write => st_next_state <= stop;
  --
  --     when stop      => if sv_dout_baud_counter >= to_unsigned(c_baud_length - 3, sv_dout_baud_counter'length) then
  --                         st_next_state <= clr_stop;
  --                       else
  --                         st_next_state <= stop;
  --                       end if;
  --     when others    => null;
  --   end case;
  -- end process transition;
  --
  -- output : process (st_state) is
  -- begin
  --   -- Default assignments for all used counters.
  --   s_enable_write_counter <= '0'; s_clr_write_counter <= '0';
  --   s_enable_baud_counter  <= '0'; s_clr_baud_counter  <= '0';
  --   -- Default assignments for all given outputs.
  --
  --   case st_state is
  --     when start     => s_enable_baud_counter  <= '1';
  --
  --     when clr_start => s_clr_baud_counter     <= '1';
  --
  --     when sleep     => s_enable_baud_counter  <= '1';
  --
  --     when clr_sleep => s_clr_baud_counter     <= '1';
  --
  --     when write     => s_enable_write_counter <= '1';
  --
  --     when clr_write => s_clr_write_counter    <= '1';
  --
  --     when stop      => s_enable_baud_counter  <= '1';
  --
  --     when clr_stop  => s_clr_baud_counter     <= '1';
  --
  --     when others    => null;
  --
  --   end case;
  -- end process output;
  -- -- }}}
  --
  input_register : process (clk, rst) is
  begin
    if rst = '1' then
      sv_din_t <= (others => '0');
    elsif clk'event and clk = '1' then
      sv_din_t <= sv_din;
    end if;
  end process input_register;

  gen_parity : case g_parity generate
    when odd    => sv_din <= din & not (xor din);
    when even   => sv_din <= din & xor din;
    when others => sv_din <= din;
  end generate gen_parity;

  busy <= '0' when st_state = idle else '1';
  dout <= '0';

  -- Those Counters build the Time-Base for our State-Machine. {{{
  baud_counter : entity uart_lib.counter
    generic map (g_length => sv_dout_baud_counter'length)
    port map (clk => clk, rst => rst, ena => s_enable_baud_counter, clr => s_clr_baud_counter, dout => sv_dout_baud_counter);

  write_counter : entity uart_lib.counter
    generic map (g_length => sv_dout_write_counter'length)
    port map (clk => clk, rst => rst, ena => s_enable_write_counter, clr => s_clr_write_counter, dout => sv_dout_write_counter);
  -- }}}

end architecture rtl;

-- vim : foldmethod = marker

