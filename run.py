#!/usr/bin/env python

import os
import glob
import shutil
import subprocess

from vunit import VUnit


def set_up_vunit():
    '''Set-Up the VUnit runtime.
    '''

    ui = VUnit.from_argv()

    ui.add_osvvm()
    ui.add_verification_components()

    tb_path = os.path.join(os.path.dirname(__file__), 'tb')
    src_path = os.path.join(os.path.dirname(__file__), 'src')

    uart_lib = ui.add_library('uart_lib')
    uart_lib.add_source_files(os.path.join(src_path, '*.vhdl'))
    #  uart_lib.add_compile_option('ghdl.flags', ['-fprofile-arcs', '-fprofile-dir=./profile', '-ftest-coverage'])

    tb_uart_lib = ui.add_library('tb_uart_lib')
    tb_uart_lib.add_source_files(os.path.join(tb_path, '*.vhdl'))
    #  tb_uart_lib.add_compile_option('ghdl.flags', ['-fprofile-arcs', '-fprofile-dir=./profile', '-ftest-coverage'])
    #  tb_uart_lib.set_sim_option('ghdl.elab_flags', ['-Wl,-lgcov'])

    tb_receiver = tb_uart_lib.entity('tb_receiver')

    transfer_single = tb_receiver.test('transfer.single')
    transfer_single.add_config(name = 'odd_parity',  generics = dict(encoded_parity = 'odd'))
    transfer_single.add_config(name = 'even_parity', generics = dict(encoded_parity = 'even'))
    transfer_single.add_config(name = 'none_parity', generics = dict(encoded_parity = 'none'))
    transfer_single.add_config(name = 'five_bits',   generics = dict(encoded_data_bits = '5'))
    transfer_single.add_config(name = 'six_bits',    generics = dict(encoded_data_bits = '6'))
    transfer_single.add_config(name = 'seven_bits',  generics = dict(encoded_data_bits = '7'))

    transfer_multi = tb_receiver.test('transfer.multi')
    transfer_multi.add_config(name = 'five_bits',       generics = dict(encoded_data_bits = '5'))
    transfer_multi.add_config(name = 'six_bits',        generics = dict(encoded_data_bits = '6'))
    transfer_multi.add_config(name = 'seven_bits',      generics = dict(encoded_data_bits = '7'))
    transfer_multi.add_config(name = '9600bps',         generics = dict(encoded_bits_per_second = '9600', encoded_ns_clock_period = '2000'))
    transfer_multi.add_config(name = '115200bps',       generics = dict(encoded_bits_per_second = '115200', encoded_ns_clock_period = '200'))
    transfer_multi.add_config(name = '500000bps',       generics = dict(encoded_bits_per_second = '500000'))
    transfer_multi.add_config(name = '100clks_per_bit', generics = dict(encoded_ns_clock_period = '20'))
    transfer_multi.add_config(name = '10clks_per_bit',  generics = dict(encoded_ns_clock_period = '200'))
    transfer_multi.add_config(name = '5clks_per_bit',   generics = dict(encoded_ns_clock_period = '400'))

    transfer_multi.add_config(name = '2000000bps@125ns', generics = dict(encoded_bits_per_second = '2000000', encoded_ns_clock_period = '125', encoded_parity = 'even'))

    try:
        ui.main()
    except SystemExit as exc:
        all_ok = exc.code == 0

    #  if all_ok:
    # FIXME: lcov versions differ (expected 8.3 got 9.1)
    if False:
        for info_file in glob.glob(r'./*.gcno'):
            shutil.move(info_file, os.path.join('./profile', info_file))

        fd_cov = 'coverage.info'

        subprocess.call(['lcov', '--capture', '--directory', '.', '--output-file',  fd_cov])
        subprocess.call(['genhtml', fd_cov, '--output-directory', 'coverage'])
        shutil.move(fd_cov, os.path.join('./coverage', fd_cov))


if __name__ == '__main__':
    set_up_vunit()
