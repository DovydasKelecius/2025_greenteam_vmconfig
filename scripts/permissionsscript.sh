#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Error: Run this script with sudo."
  exit 1
fi

sudo apt update && sudo apt upgrade -y

sudo apt install cron -y
sudo systemctl enable cron
sudo systemctl start cron

sudo useradd -m -s /bin/bash lowpriv
echo "lowpriv:slaptazodis" | sudo chpasswd
sudo useradd -m -s /bin/bash highpriv
echo "highpriv:saugussslaptazodis" | sudo chpasswd

sudo -u highpriv bash -c '
  mkdir ~/secrets
  echo "FLAG: wooo radot flag'a" > ~/secrets/flag.txt
  chmod 600 ~/secrets/flag.txt
  chown highpriv:highpriv ~/secrets/flag.txt
  chmod 711 ~/secrets
'

sudo mkdir /shared
sudo chown highpriv:highpriv /shared
sudo chmod 777 /shared
echo "This is a shared workspace." | sudo tee /shared/readme.txt
sudo chmod 644 /shared/readme.txt

echo "* * * * * /bin/cp /shared/* /tmp/ 2>/dev/null" | sudo tee /tmp/crontab_tmp
sudo crontab -u root /tmp/crontab_tmp
sudo rm /tmp/crontab_tmp

echo "Gali buti jog viskas gerai susinstaliavosi (arba ne), prisijungimo vardas: lowpriv (slaptazodis: slaptazodis)."