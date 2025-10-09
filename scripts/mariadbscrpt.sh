#!/bin/bash

set- e

apt update
apt install -y mariadb-server mariadb-client apache2

systemctl enable mariadb
systemctl start mariadb
systemctl enable apache2
systemctl start apache2

CONFIG_FILE="/etc/mysql/mariadb.conf.d/50-server.cnf"
sed -i 's/bind-address.*/bind-address = 0.0.0.0/' "$CONFIG_FILE"

systemctl restart mariadb

mariadb -u root -e "CREATE DATABASE duoNbaze;"
mariadb -u root -e "CREATE USER 'sapiens'@'%' IDENTIFIED BY '04102025';"
mariadb -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'sapiens'@'%' WITH GRANT OPTION;"
mariadb -u root -e "FLUSH PRIVILEGES;"

mkdir -p /var/www/html/site/institute
cat << EOF >> /var/www/html/site/institute/.env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=duoNbaze
DB_USERNAME=sapiens
DB_PASSWORD=04102025
EOF

chmod 644 /var/www/html/site/institute/.env

ufw allow 3306/tcp
ufw --force enable

echo "<Directory /var/www/html/site/insitute>" >> /etc/apache2/sites-available/000-default.conf
echo "	Options +Indexes" >> /etc/apache2/sites-available/000-default.conf
echo "</Directory>" >> /etc/apache2/sites-available/000-default.conf

systemctl restart apache2

echo "Setup complete"
