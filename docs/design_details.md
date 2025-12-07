# Design Details: Custom SPI Master IP Core

This document explains the internal logic, timing flags, and functional behavior of a custom-designed SPI Master IP Core with APB interface, written in Verilog.

---

## 1. SPI Modes (CPOL & CPHA)

| Mode | CPOL | CPHA | Clock Idle | Sample Edge | Shift Edge |
|------|------|------|-------------|--------------|-------------|
| 0    | 0    | 0    | LOW         | Rising       | Falling     |
| 1    | 0    | 1    | LOW         | Falling      | Rising      |
| 2    | 1    | 0    | HIGH        | Falling      | Rising      |
| 3    | 1    | 1    | HIGH        | Rising       | Falling     |

Modes are set using `CPOL` and `CPHA` bits in `SPI_CR1`.

---

## 2. Timing Flags

These internal flags coordinate SPI bit-level timing:

| Signal         | Function                                                   |
|----------------|------------------------------------------------------------|
| `flags_low`    | MOSI shift: 1 cycle before SCLK falling edge               |
| `flags_high`   | MOSI shift: 1 cycle before SCLK rising edge                |
| `flag_low`     | MISO sample: at SCLK falling edge                          |
| `flag_high`    | MISO sample: at SCLK rising edge                           |

Timing behavior is driven by `(CPOL XOR CPHA)` logic.

---

## 3. Shift Register Logic

- 8-bit parallel-to-serial and serial-to-parallel operation
- Shift direction controlled by `LSBFE`:
  - `0`: MSB first
  - `1`: LSB first
- Captures MISO using `flag_low` / `flag_high`
- Triggers transfer with `send_data`, completes with `receive_data`

---

## 4. Slave Select (`ss`) Control

The SPI master automatically manages the active-low `ss` line:

1. `ss` goes LOW one cycle after `send_data` is asserted.
2. Remains LOW during the 8-bit transfer (16 SCLK edges).
3. Goes HIGH again after completion and `receive_data` is asserted.

Transfer length is governed by:  
`target_count = baud_divisor × 16`

---

## 5. Baud Rate Generator

### Formula
```
BaudRateDivisor = (SPPR + 1) × 2^(SPR + 1)
```


- Controlled via `SPI_BR` register
- Generates SCLK from PCLK
- Output toggles at programmable rate

---

## 6. FSM Overview

### APB FSM
| State  | Description              |
|--------|--------------------------|
| IDLE   | Wait for APB transaction |
| SETUP  | Latch address/data       |
| ENABLE | Perform read/write       |

### SPI FSM
| State | Description                      |
|-------|----------------------------------|
| RUN   | SPI active                       |
| WAIT  | SPI disabled but ready           |
| STOP  | Clock disabled (power-saving)    |

---

## 7. Register Map

| Addr | Register   | Access | Description                         |
|------|------------|--------|-------------------------------------|
| 0x00 | SPI_CR1    | RW     | CPOL, CPHA, MSTR, LSBFE             |
| 0x01 | SPI_CR2    | RW     | SPISWAI, interrupts                 |
| 0x02 | SPI_BR     | RW     | SPPR, SPR for baud configuration   |
| 0x03 | SPI_SR     | RO     | Status flags (SPIF, SPTEF, MODF)   |
| 0x05 | SPI_DR     | RW     | TX (write) / RX (read) data        |

Reserved bits are masked during write operations.

---

## 8. Interrupt Logic

- Interrupt request line is asserted when:
  - `SPIF = 1` (transfer complete)
  - `MODF = 1` (mode fault)
- Control via bits in `SPI_CR2`
- Output: `spi_interrupt_request`

---

## References

- **AMBA APB Protocol Specification** – ARM_AMBA3_APB
- **Serial Peripheral Interface (SPI) Block Guide – S12SPIV3** – Motorola
- **WAVEFORMS.pdf** for simulation results

---

## Legal Notice

This document was prepared for educational purposes only. It contains original logic developed independently and may conceptually reference open SPI/APB standards for compatibility. No proprietary information is disclosed.

