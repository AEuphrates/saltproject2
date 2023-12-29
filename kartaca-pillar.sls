kartaca:
  user: kartaca
  password: kartaca2023
  uid: 2023
  gid: 2023
  home: /home/krt
  shell: /bin/bash
  sudo_privileges:
    - "ALL=(ALL) NOPASSWD: /usr/bin/yum"
    - "ALL=(ALL) NOPASSWD: /usr/bin/apt"
  mysql:
    db_name: mydatabase
    db_user: myuser
    db_password: mypassword
  nginx:
    ssl_cert_path: /etc/nginx/ssl/kartaca.crt
    ssl_key_path: /etc/nginx/ssl/kartaca.key
    nginx_conf_path: /etc/nginx/nginx.conf
