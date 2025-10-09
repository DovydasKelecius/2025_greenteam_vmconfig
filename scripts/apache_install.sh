#!/usr/bin/env bash
#

set -e

if [[ "$EUID" -ne 0 ]]; then
    echo "Run as root!"
    exit 1
fi


apt update -y
apt install gcc curl libpcre3-dev make wget libapr1-dev libaprutil1-dev -y

wget https://archive.apache.org/dist/httpd/httpd-2.4.49.tar.bz2
tar -xvjf 'httpd-2.4.49.tar.bz2'
cd "httpd-2.4.49" || exit 1

./configure --prefix="/usr/local/apache2"
make
make install

cat << "EOF" > "/usr/local/apache2/conf/httpd.conf"
ServerRoot "/usr/local/apache2"

# FIX: Changed Listen 80 to 8080 to avoid "Address already in use" conflict.
Listen 8080

# FIX: Added ServerName to suppress the AH00558 warning.
ServerName localhost:8080

LoadModule authn_file_module modules/mod_authn_file.so
LoadModule authn_core_module modules/mod_authn_core.so
LoadModule authz_host_module modules/mod_authz_host.so
LoadModule authz_groupfile_module modules/mod_authz_groupfile.so
LoadModule authz_user_module modules/mod_authz_user.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule access_compat_module modules/mod_access_compat.so
LoadModule auth_basic_module modules/mod_auth_basic.so
LoadModule reqtimeout_module modules/mod_reqtimeout.so
LoadModule filter_module modules/mod_filter.so
LoadModule mime_module modules/mod_mime.so
LoadModule log_config_module modules/mod_log_config.so
LoadModule env_module modules/mod_env.so
LoadModule headers_module modules/mod_headers.so
LoadModule setenvif_module modules/mod_setenvif.so
LoadModule version_module modules/mod_version.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule status_module modules/mod_status.so
LoadModule autoindex_module modules/mod_autoindex.so
LoadModule cgid_module modules/mod_cgid.so
LoadModule dir_module modules/mod_dir.so
LoadModule alias_module modules/mod_alias.so

<IfModule unixd_module>
User daemon
Group daemon
</IfModule>
ServerAdmin you@example.com
<Directory />
    AllowOverride none
    Require all granted
</Directory>

DocumentRoot "/usr/local/apache2/htdocs"
<Directory "/usr/local/apache2/htdocs">
    Options Indexes FollowSymLinks
    AllowOverride None
    Require all granted
</Directory>

<IfModule dir_module>
    DirectoryIndex index.html
</IfModule>
<Files ".ht*">
    Require all granted
</Files>

ErrorLog "logs/error_log"
LogLevel warn

<IfModule log_config_module>
    LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\"" combined
    LogFormat "%h %l %u %t \"%r\" %>s %b" common
    <IfModule logio_module>
      LogFormat "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\" %I %O" combinedio
    </IfModule>
    CustomLog "logs/access_log" common
</IfModule>

<IfModule alias_module>
    ScriptAlias /cgi-bin/ "/usr/local/apache2/cgi-bin/"
</IfModule>

<IfModule cgid_module>
    Scriptsock cgisock
</IfModule>

<Directory "/usr/local/apache2/cgi-bin">
    AllowOverride None
    Options +ExecCGI
    Require all granted
</Directory>

<IfModule headers_module>
    RequestHeader unset Proxy early
</IfModule>

<IfModule mime_module>
    TypesConfig conf/mime.types
    AddType application/x-compress .Z
    AddType application/x-gzip .gz .tgz

    AddHandler cgi-script .cgi
    AddHandler cgi-script .sh
</IfModule>

<IfModule proxy_html_module>
Include conf/extra/proxy-html.conf
</IfModule>
<IfModule ssl_module>
SSLRandomSeed startup builtin
SSLRandomSeed connect builtin
</IfModule>

EOF

# This line introduces the critical vulnerability detailed in the summary!
chmod 777 -R "/usr/local/apache2/"

cat << "EOF" > "/usr/local/apache2/cgi-bin/test.sh"
#!/usr/bin/env bash
echo "Content-type: text/html"
echo ""
echo "<html><body><h1>Hello from CGI! \$HOME </h1></body></html>"

text=$(cat /etc/passwd)

/bin/bash -c "echo text: \$(hostname)"
/bin/bash -c "echo t: \$text"
#echo "$HOME"

#touch ~atest
#
#touch /home/andrey/hello
EOF

chmod 777 -R "/usr/local/apache2/cgi-bin"

cat << "EOF" > "/etc/systemd/system/httpd.service"
[Unit]
Description="The Apache HTTP Server"
After=network.target

[Service]
Type=forking

ExecStart=/usr/local/apache2/bin/apachectl start
ExecReload=/usr/local/apache2/bin/apachectl graceful
ExecStop=/usr/local/apache2/bin/apachectl stop

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

"/usr/local/apache2/bin/apachectl" start
