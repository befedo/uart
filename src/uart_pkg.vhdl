library ieee;
  use ieee.numeric_std.all;
  use ieee.std_logic_1164.all;


package receiver_utils is
  -- 't_act' is used in the receiver testbench to define the senders state.
  type t_act is (idle, start, data, parity, stop);
  -- 't_parity' is used inside the receiver/transmitter modules to define the senders parity.
  type t_parity is (none, even, odd);
  -- 'do_rst' generates the reset mechinsm for our receiver module.
  procedure do_rst ( constant ns_period : in    positive
                   ; signal   rst       : inout std_ulogic
                  );
  -- 'do_tx' writes a single byte like an UART on dout.
  procedure do_tx ( constant value  : in  integer
                  ; constant delay  : in  time
                  ; constant bitnum : in  integer
                  ; constant par    : in  t_parity
                  ; signal   tx     : out std_ulogic
                  ; signal   act    : out t_act
                  ; signal   dout   : out integer
                 );
  -- 'do_rx' reads a single byte like an UART on dout.
  procedure do_rx ( constant delay  : in  time
                  ; constant bitnum : in  integer
                  ; constant par    : in  t_parity
                  ; signal   rx     : in  std_ulogic
                  ; signal   act    : out t_act
                  ; signal   dout   : out integer
                 );
  -- 'decode_parity' derives from a VUnit String the needed 't_parity' type.
  function decode_parity (p : string) return t_parity;
  -- 'check_parity' returns true when the parity of 'data' is like defined through 't_parity'.
  function check_parity (constant p : t_parity; constant value : std_ulogic_vector) return boolean;
end package receiver_utils;

library ieee;
  use ieee.numeric_std.all;
  use ieee.std_logic_1164.all;


package body receiver_utils is

  procedure do_rst (constant ns_period : in positive; signal rst : inout std_ulogic) is
  begin
    rst <= '1';
    wait for (10*ns_period/2) * 1 ns;
    rst <= '0';
    wait for (10*ns_period/2) * 1 ns;
  end procedure do_rst;

  procedure do_tx ( constant value  : in  integer
                  ; constant delay  : in  time
                  ; constant bitnum : in  integer
                  ; constant par    : in  t_parity
                  ; signal   tx     : out std_ulogic
                  ; signal   act    : out t_act
                  ; signal   dout   : out integer
                  )
  is
    constant cv_value : std_ulogic_vector (bitnum - 1 downto 0) := std_ulogic_vector (to_unsigned(value, bitnum));
  begin
    -- TODO: Initial delay should be randomly between one and some bits.
    wait for 3 * delay;
    dout <= value;
    act <= start;
    tx <= '0';
    wait for delay;
    act <= data;
    for i in cv_value'range loop
      tx <= cv_value(i);
      wait for delay;
    end loop;
    gen_parity : case par is
      when odd    => act <= parity;
                     tx <= not (xor cv_value);
                     wait for delay;
      when even   => act <= parity;
                     tx <= xor cv_value;
                     wait for delay;
      when others => null;
    end case gen_parity;
    act <= stop;
    tx <= '1';
    wait for 1.5 * delay;
    act <= idle;
  end procedure do_tx;


  procedure do_rx ( constant delay  : in  time
                  ; constant bitnum : in  integer
                  ; constant par    : in  t_parity
                  ; signal   rx     : in  std_ulogic
                  ; signal   act    : out t_act
                  ; signal   dout   : out integer
                  )
  is
    variable sv_value : std_ulogic_vector (bitnum - 1 downto 0);
  begin
    wait until rx'event and rx = '0';
    act <= start;
    wait for delay;
    act <= data;
    wait for 0.5 * delay;
    for i in sv_value'range loop
      sv_value(i) := rx;
      wait for delay;
    end loop;
    -- TODO: assert on parity
    check : case par is
      when odd    => act <= parity;
                     wait for delay;
      when even   => act <= parity;
                     wait for delay;
      when others => null;
    end case check;
    act <= stop;
    dout <= to_integer(unsigned(sv_value));
    wait for 1.5 * delay;
    act <= idle;
  end procedure do_rx;

  function decode_parity (p : string) return t_parity is
  begin
    if    p =  "odd" then return  odd;
    elsif p = "even" then return even;
    else                       return none;
    end if;
  end function decode_parity;

  function check_parity (constant p : t_parity; constant value : std_ulogic_vector) return boolean is
    variable sum : natural := 0;
  begin
    if p = none then
      return true;
    else
      for i in value'range loop
       if value(i) = '1' then
          sum := sum + 1;
        end if;
      end loop;
    end if;

    case p is
      when odd    => return sum mod 2 = 1;
      when even   => return sum mod 2 = 0;
      when others => return false;
    end case;
  end function check_parity;
end package body receiver_utils;

