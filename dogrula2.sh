#!/usr/bin/env bash
# MySQL verification with time sync OFF: the same operations after 2038 / in 2037 / after 2038 again.
set -u
cd /root/deney
q(){ echo "-- $*"; mysql -e "$*" 2>&1; }
timedatectl set-ntp false; sleep 2
{
date -u -s '2038-01-19 03:20:00' > /dev/null
echo "== saat: $(date -u '+%F %T')  (2038 sonrası)"
q "INSERT INTO d.notes (body) VALUES ('default, after 2038');"
q "INSERT INTO d.notes (body, created_at) VALUES ('explicit literal', '2038-01-19 03:20:01');"
q "INSERT INTO d.notes (body, created_at) VALUES ('explicit NOW()', NOW());"
q "UPDATE d.notes SET body = CONCAT(body, ' (updated)') WHERE id = 1;"
q "CREATE TABLE d.yeni2038 (id INT);"
q "CREATE DATABASE yeni_db_2038;"
q "SELECT id, body, created_at, UNIX_TIMESTAMP(created_at) FROM d.notes ORDER BY id;"
date -u -s '2037-12-31 23:00:00' > /dev/null
echo "== saat: $(date -u '+%F %T')  (2038 öncesi)"
q "CREATE TABLE d.yeni2037 (id INT);"
q "INSERT INTO d.notes (body) VALUES ('default, 2037');"
date -u -s '2038-01-19 03:30:00' > /dev/null
echo "== saat: $(date -u '+%F %T')  (yeniden 2038 sonrası)"
q "CREATE TABLE d.yeni2038b (id INT);"
echo "== mysql yeniden başlatma (2038 sonrası)"
systemctl restart mysql 2>&1; sleep 3; systemctl is-active mysql
q "SELECT NOW(), (SELECT COUNT(*) FROM d.notes) AS satir;"
q "SELECT TABLE_NAME, CREATE_TIME FROM information_schema.tables WHERE table_schema='d';"
journalctl -u mysql --since '2038-01-19 03:29:00' --no-pager 2>&1 | tail -5
tail -5 /var/log/mysql/error.log
} > dogrula2.txt 2>&1
timedatectl set-ntp true
