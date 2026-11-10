#!/usr/bin/env bash
# Does CREATE TABLE / CREATE DATABASE break after 2038? Time sync off, a new name every time.
set -u
q(){ echo "-- $*"; mysql -e "$*" 2>&1; }
timedatectl set-ntp false; sleep 2
{
for t in "2038-01-19 03:40:00|a1" "2037-12-31 23:00:00|b1" "2038-01-19 03:41:00|a2" "2038-01-19 03:14:07|c1" "2038-01-19 03:14:09|c2"; do
  when="${t%%|*}"; tag="${t##*|}"
  date -u -s "$when" > /dev/null
  echo "== saat: $(date -u '+%F %T')"
  q "CREATE TABLE d.ddl_$tag (id INT);"
  q "CREATE DATABASE db_$tag;"
done
echo "== hangi tablolar oluştu"
q "SELECT TABLE_NAME, CREATE_TIME FROM information_schema.tables WHERE table_schema='d' AND TABLE_NAME LIKE 'ddl%';"
q "SHOW DATABASES LIKE 'db_%';"
} > /root/deney/dogrula3.txt 2>&1
timedatectl set-ntp true
