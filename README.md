# uart

UART implementation in VHDL from the 'ecl' department at Saale-Logic.

## Description

This Repository contains a VHDL implementation of an *U*niversal *A*synchronous *R*eceiver/*T*ransmitter.

## Utilization

Currently following hardware resources were used:

### Slice Logic

+-------------------------+------+-------+-----------+-------+
|        Site Type        | Used | Fixed | Available |     % |
+=========================+======+=======+===========+=======+
| Slice LUTs              |   56 |     0 |     20800 |  0.27 |
|   LUT as Logic          |   56 |     0 |     20800 |  0.27 |
|   LUT as Memory         |    0 |     0 |      9600 |  0.00 |
| Slice Registers         |   56 |     0 |     41600 |  0.13 |
|   Register as Flip Flop |   56 |     0 |     41600 |  0.13 |
|   Register as Latch     |    0 |     0 |     41600 |  0.00 |
| F7 Muxes                |   14 |     0 |     16300 |  0.09 |
| F8 Muxes                |    7 |     0 |      8150 |  0.09 |
+-------------------------+------+-------+-----------+-------+

### Summary of Registers by Type

+-------+--------------+-------------+--------------+
| Total | Clock Enable | Synchronous | Asynchronous |
+=======+==============+=============+==============+
| 0     |            - |           - |            - |
| 0     |            - |           - |          Set |
| 0     |            - |           - |        Reset |
| 0     |            - |         Set |            - |
| 0     |            - |       Reset |            - |
| 0     |          Yes |           - |            - |
| 15    |          Yes |           - |          Set |
| 41    |          Yes |           - |        Reset |
| 0     |          Yes |         Set |            - |
| 0     |          Yes |       Reset |            - |
+-------+--------------+-------------+--------------+


### Slice Logic Distribution

+--------------------------------------------+------+-------+-----------+-------+
|                  Site Type                 | Used | Fixed | Available | Util% |
+============================================+======+=======+===========+=======+
| Slice                                      |   20 |     0 |      8150 |  0.25 |
|   SLICEL                                   |   11 |     0 |           |       |
|   SLICEM                                   |    9 |     0 |           |       |
| LUT as Logic                               |   56 |     0 |     20800 |  0.27 |
|   using O5 output only                     |    0 |       |           |       |
|   using O6 output only                     |   40 |       |           |       |
|   using O5 and O6                          |   16 |       |           |       |
| LUT as Memory                              |    0 |     0 |      9600 |  0.00 |
|   LUT as Distributed RAM                   |    0 |     0 |           |       |
|   LUT as Shift Register                    |    0 |     0 |           |       |
| Slice Registers                            |   56 |     0 |     41600 |  0.13 |
|   Register driven from within the Slice    |   39 |       |           |       |
|   Register driven from outside the Slice   |   17 |       |           |       |
|     LUT in front of the register is unused |   14 |       |           |       |
|     LUT in front of the register is used   |    3 |       |           |       |
| Unique Control Sets                        |    5 |       |      8150 |  0.06 |
+--------------------------------------------+------+-------+-----------+-------+

### Clocking

+------------+------+-------+-----------+-------+
|  Site Type | Used | Fixed | Available | Util% |
+============+======+=======+===========+=======+
| BUFGCTRL   |    2 |     0 |        32 |  6.25 |
| BUFIO      |    0 |     0 |        20 |  0.00 |
| MMCME2_ADV |    0 |     0 |         5 |  0.00 |
| PLLE2_ADV  |    1 |     0 |         5 | 20.00 |
| BUFMRCE    |    0 |     0 |        10 |  0.00 |
| BUFHCE     |    0 |     0 |        72 |  0.00 |
| BUFR       |    0 |     0 |        20 |  0.00 |
+------------+------+-------+-----------+-------+

### Primitives

+-----------+------+---------------------+
|  Ref Name | Used | Functional Category |
+===========+======+=====================+
| OBUF      |   45 |                  IO |
| FDCE      |   41 |        Flop & Latch |
| LUT4      |   36 |                 LUT |
| LUT5      |   15 |                 LUT |
| LUT2      |   15 |                 LUT |
| FDPE      |   15 |        Flop & Latch |
| MUXF7     |   14 |               MuxFx |
| IBUF      |    8 |                  IO |
| MUXF8     |    7 |               MuxFx |
| LUT6      |    4 |                 LUT |
| BUFG      |    2 |               Clock |
| PLLE2_ADV |    1 |               Clock |
| LUT3      |    1 |                 LUT |
| LUT1      |    1 |                 LUT |
| DSP48E1   |    1 |    Block Arithmetic |
+-----------+------+---------------------+
