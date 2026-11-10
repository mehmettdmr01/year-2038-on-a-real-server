# What breaks on a server at 03:14:08 on 19 January 2038?

Video: (link coming)

Unix time counts seconds since 1 January 1970. Stored in a signed 32-bit integer, it runs out at 2,147,483,647, which is 03:14:07 UTC on 19 January 2038. One second later it wraps to -2,147,483,648, which reads as 13 December 1901.

I rented an ordinary $6 DigitalOcean server, turned off time sync, set the clock to 03:13:58 on 19 January 2038 and recorded five things every second. Everything here is the real script and the real output.

## Setup
DigitalOcean s-1vcpu-1gb (ams3), Ubuntu 24.04.5 LTS, kernel 6.8.0-147 x86_64, gcc 13.3.0, MySQL 8.0.46 (Ubuntu's package). Run on 10 November 2026. Exact versions: `sonuc/surumler.txt`.

## Results

| Test | Up to 03:14:07 | 03:14:08 and after |
|---|---|---|
| 64-bit program, `time()` (time_t 8 bytes) | normal | 2147483648, 2147483649 … keeps counting |
| Same program built 32-bit (`gcc -m32`, time_t 4 bytes) | normal | `time()` = -1, errno "Value too large for defined data type", date 1969-12-31 23:59:59 |
| Time stored in a 32-bit field (`int32_t`) | normal | 1901-12-13 20:45:52, then 20:45:53 … |
| ext4 made with 128-byte inodes (`mkfs.ext4 -I 128`) | kernel warns on mount: "supports timestamps until 2038-01-19 (0x7fffffff)" | a file written at 03:14:16 shows 03:14:07; a file dated 2040-06-01 also shows 03:14:07 |
| ext4 with default 256-byte inodes | normal | 03:14:16 and 2040-06-01 stored correctly |
| MySQL `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP` | normal | the default insert is accepted and stores 2038-01-19 03:14:16 (the documented TIMESTAMP range ends at 03:14:07) |
| MySQL, same column, `NOW()` or a typed date | normal | ERROR 1292 Incorrect datetime value |
| MySQL `CREATE TABLE` / `CREATE DATABASE` | worked at 2037-12-31 23:00:00 and at 2038-01-19 03:14:07 | ERROR 3507 "Failed to update tables / schemata dictionary object" at 03:14:09, 03:40 and 03:41 |
| MySQL restart, reading and updating existing rows | | worked |
| Side effect: HTTPS (`curl https://www.google.com`) | | "certificate has expired": today's certificates are expired in 2038. Not the 2038 bug itself. |

## Files
Names are Turkish, as shown in the video:
- `deney.sh` (experiment): the whole run.
- `saat.c` (clock): prints `time()`; built as 64-bit and 32-bit.
- `alan32.c` (32-bit field): reads the clock correctly and stores it in an `int32_t`.
- `dogrula2.sh`, `dogrula3.sh` (verify): the MySQL checks with time sync off, including the back-and-forth clock test for `CREATE TABLE`.
- `sonuc/` (results): every raw output.
  - `saniye.log`: one line per second.
  - `mysql-sonra.txt`: MySQL after the jump.
  - `ext4-*.txt`: both disks.
  - `yan-gozlem.txt`: side effects.
  - `dogrula2.txt`, `dogrula3.txt`: the MySQL verification.

The program output contains a few Turkish words:
- `bayt` = bytes
- `yok` = none
- `gercek` = real
- `int32 alanda` = in the int32 field

A first verification run (`dogrula.sh`) is not included: time sync was still on, so the clock jumped back to 2026 and the results were invalid.

## Run it yourself
Only on a throwaway machine: the script installs MySQL, mounts loop disks and sets the system clock to 2038.
```
bash deney.sh            # results in /root/deney
bash dogrula3.sh         # CREATE TABLE before and after 03:14:07
```
Before any `date -s` test, turn time sync off with `timedatectl set-ntp false`, or the clock is pulled back within seconds.

## Limits
- One server, one version of each piece of software.
- The clock was moved forward; time did not really pass.
- Not tested: MariaDB, PostgreSQL, newer MySQL versions, and a 32-bit operating system itself.
- The exact internal cause of MySQL's ERROR 3507 is not confirmed. The error message points at the data dictionary; a creation-time field hitting the same limit is a guess.

If you know something else that breaks in 2038, open an issue.
