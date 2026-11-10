#!/usr/bin/env bash
# The 2038 experiment (10 Nov 2026): sets a rented Ubuntu 24.04 server's clock to 03:13:58 UTC on 19 Jan 2038 and
# records what breaks at 03:14:07 -> 03:14:08. Run only on a throwaway machine; results go to /root/deney.
# Tests: (1) the system itself, (2) a 32-bit program and a time stored in a 32-bit field, (3) MySQL TIMESTAMP,
# (4) ext4 in the old format (128-byte inodes). Side observations: HTTPS and failed services after the jump.
set -u
OUT=/root/deney; mkdir -p "$OUT"; cd "$OUT"
export DEBIAN_FRONTEND=noninteractive
cloud-init status --wait >/dev/null 2>&1 || true
systemctl stop unattended-upgrades apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
apt-get -o DPkg::Lock::Timeout=300 update -q >/dev/null 2>&1
apt-get -o DPkg::Lock::Timeout=300 install -y -q gcc gcc-multilib mysql-server >/dev/null 2>&1
{ date -u; uname -srm; lsb_release -ds; gcc --version | head -1; mysql --version; echo "LONG_BIT=$(getconf LONG_BIT)"; } > surumler.txt 2>&1

# --- programs
cat > saat.c <<'C'
#include <stdio.h>
#include <time.h>
#include <errno.h>
#include <string.h>
int main(void) {
  errno = 0;
  time_t t = time(NULL);
  int e = errno;
  char buf[32] = "(gmtime NULL)";
  struct tm *g = gmtime(&t);
  if (g) strftime(buf, sizeof buf, "%Y-%m-%d %H:%M:%S", g);
  printf("time_t %zu bayt, time()=%lld, %s, errno=%s", sizeof(time_t), (long long)t, buf, e ? strerror(e) : "yok");
  return 0;
}
C
cat > alan32.c <<'C'
#include <stdio.h>
#include <stdint.h>
#include <time.h>
int main(void) {            /* a timestamp kept in a 32-bit field, like old code, file formats and DB columns */
  time_t now = time(NULL);
  int32_t stored = (int32_t)now;
  time_t back = stored;
  char a[32], b[32];
  strftime(a, sizeof a, "%Y-%m-%d %H:%M:%S", gmtime(&now));
  strftime(b, sizeof b, "%Y-%m-%d %H:%M:%S", gmtime(&back));
  printf("gercek %s, int32 alanda %s (%d)", a, b, stored);
  return 0;
}
C
gcc -O0 -o saat64 saat.c && gcc -m32 -O0 -o saat32 saat.c && gcc -O0 -o alan32 alan32.c
file saat64 saat32 > ikili.txt 2>&1

# --- MySQL: a typical table, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
mysql -e "CREATE DATABASE d; CREATE TABLE d.notes (id INT AUTO_INCREMENT PRIMARY KEY, body VARCHAR(40),
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, created_dt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP);
  INSERT INTO d.notes (body) VALUES ('before 2038');" > mysql-once.txt 2>&1

# --- ext4: the old format (128-byte inodes) and today's default (256)
truncate -s 64M e128.img; mkfs.ext4 -q -F -I 128 e128.img >/dev/null 2>&1
truncate -s 64M e256.img; mkfs.ext4 -q -F e256.img >/dev/null 2>&1
mkdir -p /mnt/e128 /mnt/e256
dmesg -C
mount -o loop e128.img /mnt/e128; mount -o loop e256.img /mnt/e256
dmesg > ext4-mount.txt
touch /mnt/e128/before /mnt/e256/before

# --- the clock jump
timedatectl set-ntp false; sleep 1
date -u -s '2038-01-19 03:13:58' > /dev/null
for i in $(seq 1 16); do
  echo "$(date -u '+%F %T') | 64bit: $(./saat64) | 32bit: $(./saat32) | $(./alan32)" >> saniye.log
  sleep 1
done
sleep 2

# --- after 03:14:08
{ echo "== INSERT varsayılan created_at ile"; mysql -e "INSERT INTO d.notes (body) VALUES ('after 2038');" 2>&1
  echo "== yalnız DATETIME sütunu kullanan tablo"; mysql -e "CREATE TABLE d.notes_dt (id INT AUTO_INCREMENT PRIMARY KEY, body VARCHAR(40), created_dt DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP); INSERT INTO d.notes_dt (body) VALUES ('after 2038'); SELECT * FROM d.notes_dt;" 2>&1
  echo "== tablo"; mysql -e "SELECT * FROM d.notes;" 2>&1
  echo "== NOW / UNIX_TIMESTAMP"; mysql -e "SELECT NOW(), UNIX_TIMESTAMP(), @@time_zone, @@sql_mode;" 2>&1
} > mysql-sonra.txt
touch /mnt/e128/after /mnt/e256/after
touch -d '2040-06-01 12:00:00' /mnt/e128/y2040 /mnt/e256/y2040
sync; umount /mnt/e128 /mnt/e256; mount -o loop e128.img /mnt/e128; mount -o loop e256.img /mnt/e256
stat -c '%n | %y' /mnt/e128/* /mnt/e256/* > ext4-stat.txt 2>&1
{ echo "== https"; curl -sS -o /dev/null -m 15 https://www.google.com 2>&1 || true
  echo "== systemctl --failed"; systemctl --failed --no-legend 2>&1
  echo "== journal hataları"; journalctl -p err --since '2038-01-19 03:13:00' --no-pager 2>&1 | tail -40
  echo "== dmesg"; dmesg | tail -20; } > yan-gozlem.txt
date -u > bitis-saati.txt
timedatectl set-ntp true
echo BITTI > bitti.txt
