{% set kartaca = salt['pillar.get']('kartaca', {}) %}

create_kartaca_user:
  user.present:
    - name: {{ kartaca.user }}
    - password: {{ kartaca.password }}
    - uid: {{ kartaca.uid }}
    - gid: {{ kartaca.gid }}
    - home: {{ kartaca.home }}
    - shell: {{ kartaca.shell }}

grant_sudo_privileges:
  file.managed:
    - name: /etc/sudoers.d/kartaca
    - source: salt://files/sudoers_kartaca
    - template: jinja
    - user: root
    - group: root
    - mode: 440

set_timezone:
  timezone.system:
    - name: Europe/Istanbul

enable_ip_forwarding:
  sysctl.present:
    - name: net.ipv4.ip_forward
    - value: 1
    - config_file: /etc/sysctl.conf

install_common_packages:
  pkg.installed:
    - pkgs:
      - htop
      - tcptraceroute
      - iputils-ping
      - dnsutils
      - sysstat
      - mtr

add_hashicorp_repository:
  cmd.run:
    - name: |
      curl -fsSL https://www.hashicorp.com/official-packaging-guide/hashiCorp.asc | apt-key add -
      echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
    - unless: test -e /etc/apt/sources.list.d/hashicorp.list

install_terraform:
  pkg.installed:
    - name: terraform
    - version: 1.6.4

add_host_entries:
  file.blockreplace:
    - name: /etc/hosts
    - marker_start: "# START KARTACA HOST ENTRIES"
    - marker_end: "# END KARTACA HOST ENTRIES"
    - content: |
        {% for i in range(128, 144) %}
        192.168.168.{{ i }} kartaca.local
        {% endfor %}
    - append_if_not_found: True

{% if grains['os_family'] == 'RedHat' %}

install_nginx:
  pkg.installed:
    - name: nginx

configure_nginx_autostart:
  service.running:
    - name: nginx
    - enable: True

install_php_packages:
  pkg.installed:
    - pkgs:
      - php-fpm
      - php-mysql

download_wordpress:
  cmd.run:
    - name: curl -o /tmp/wordpress.tar.gz https://wordpress.org/latest.tar.gz
    - unless: test -e /tmp/wordpress.tar.gz

unpack_wordpress:
  archive.extracted:
    - name: /var/www/wordpress2023
    - source: /tmp/wordpress.tar.gz
    - source_hash: md5=HASH_FROM_WORDPRESS_OR_SKIP_THIS_CHECK

configure_nginx_reload:
  cmd.run:
    - name: service nginx reload
    - onchanges:
      - file: {{ kartaca.nginx.nginx_conf_path }}

configure_wp_config:
  cmd.run:
    - name: |
      sed -i "s/database_name_here/{{ kartaca.mysql.db_name }}/g" /var/www/wordpress2023/wp-config.php
      sed -i "s/username_here/{{ kartaca.mysql.db_user }}/g" /var/www/wordpress2023/wp-config.php
      sed -i "s/password_here/{{ kartaca.mysql.db_password }}/g" /var/www/wordpress2023/wp-config.php
    - onchanges:
      - cmd: configure_nginx_reload

generate_salt_keys:
  cmd.run:
    - name: curl -s https://api.wordpress.org/secret-key/1.1/salt/
    - onchanges:
      - cmd: configure_wp_config

create_ssl_certificate:
  cmd.run:
    - name: |
      openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout {{ kartaca.nginx.ssl_key_path }} -out {{ kartaca.nginx.ssl_cert_path }} -subj "/C=US/ST=CA/L=San Francisco/O=Example/OU=IT Department/CN=kartaca.local"
    - unless: test -e {{ kartaca.nginx.ssl_key_path }} and test -e {{ kartaca.nginx.ssl_cert_path }}
    - onchanges:
      - cmd: configure_nginx_reload

manage_nginx_config:
  file.managed:
    - name: {{ kartaca.nginx.nginx_conf_path }}
    - source: salt://files/nginx.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - onchanges:
      - cmd: configure_nginx_reload

create_nginx_restart_cron:
  cron.present:
    - name: Restart Nginx
    - user: root
    - command: service nginx restart
    - minute: 0
    - hour: 0
    - daymonth: 1

configure_nginx_logrotate:
  file.managed:
    - name: /etc/logrotate.d/nginx
    - source: salt://files/nginx_logrotate.conf
    - template: jinja
    - user: root
    - group: root
    - mode: 644


{% elif grains['os_family'] == 'Debian' %}
install_mysql:
  pkg.installed:
    - name: mysql-server

configure_mysql_autostart:
  service.running:
    - name: mysql
    - enable: True

create_mysql_database_user:
  mysql_user.present:
    - name: {{ kartaca.mysql.db_user }}
    - password: {{ kartaca.mysql.db_password }}
    - host: localhost

create_mysql_database:
  mysql_database.present:
    - name: {{ kartaca.mysql.db_name }}
    - owner: {{ kartaca.mysql.db_user }}

prepare_mysql_backup_cron:
  cron.present:
    - name: MySQL Database Backup
    - user: root
    - command: /usr/bin/mysqldump -u{{ kartaca.mysql.db_user }} -p{{ kartaca.mysql.db_password }} {{ kartaca.mysql.db_name }} > /backup/{{ kartaca.mysql.db_name }}_$(date +\%Y\%m\%d\%H\%M).sql
    - minute: 0
    - hour: 2

{% endif %}
