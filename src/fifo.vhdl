library ieee;
  use ieee.numeric_std.all;
  use ieee.std_logic_1164.all;
  use ieee.math_real.log2;

entity fifo is
  generic ( g_width  : positive := 8
          ; g_length : positive := 16
         );
  port ( clk, rst, we_i, re_i    : in  std_ulogic
       ; data_i                  : in  std_ulogic_vector (g_width - 1 downto 0)
       ; full_o, empty_o         : out std_ulogic
       ; underflow_o, overflow_o : out std_ulogic
       ; data_o                  : out std_ulogic_vector (g_width - 1 downto 0)
      );
end entity fifo;

architecture pow2 of fifo is
  type t_mem is array (0 to (2**g_length) - 1) of unsigned (g_width - 1 downto 0);

  signal sa_mem                      : t_mem;
  signal s_full, s_empty             : std_logic;
  signal sv_read_addr, sv_write_addr : unsigned (g_length - 1 downto 0);
begin
  process (rst, clk) is
  begin
    if rst then
      (sv_read_addr, sv_write_addr) <= to_unsigned(0, sv_read_addr'length + sv_write_addr'length);
    elsif clk'event and clk = '1' then
      if we_i and not s_full then
        sa_mem(to_integer(sv_write_addr)) <= unsigned(data_i);
        sv_write_addr <= sv_write_addr + 1;
      end if;
      if re_i and not s_empty then
        data_o <= std_logic_vector(sa_mem(to_integer(sv_read_addr)));
        sv_read_addr <= sv_read_addr + 1;
      end if;
    end if;
  end process;

  s_full  <= '1' when sv_read_addr = sv_write_addr + 1 else '0';
  s_empty <= '1' when sv_read_addr = sv_write_addr     else '0';

  full_o  <= s_full;
  empty_o <= s_empty;

end architecture pow2;

-- FIXME: Overflow is of by one increment each iteration.
architecture pown of fifo is
  type t_mem is array (0 to (2**g_length) - 1) of unsigned (g_width - 1 downto 0);

  signal memory                      : t_mem;
  signal s_full, s_empty             : std_logic;
  signal sv_read_addr, sv_write_addr : integer range 0 to (2**g_length) - 1;
begin
  process (rst, clk) is
  begin
    if rst then
      sv_read_addr <= 0;
      sv_write_addr <= 0;
    elsif clk'event and clk = '1' then
      if we_i and not s_full then
         memory(sv_write_addr) <= unsigned(data_i);
         sv_write_addr <= (sv_write_addr + 1) mod (2**g_length);
      end if;
      if re_i and not s_empty then
         data_o <= std_logic_vector(memory(sv_read_addr));
         sv_read_addr <= (sv_read_addr + 1) mod (2**g_length);
      end if;
    end if;
  end process;

  s_full  <= '1' when sv_read_addr = (sv_write_addr + 1) mod (2**g_length) else '0';
  s_empty <= '1' when sv_read_addr =  sv_write_addr                        else '0';

  full_o  <= s_full;
  empty_o <= s_empty;
end pown;
