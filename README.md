# Server Management

## Initial Server Setup

When you first create a new Ubuntu 18.04 server, there are a few configuration steps that you should take early on as part of the basic setup. This will increase the security and usability of your server and will give you a solid foundation for subsequent actions. [Read more here](https://www.digitalocean.com/community/tutorials/automating-initial-server-setup-with-ubuntu-18-04).

When the initial server setup script runs, the following actions are performed:

- Create a regular user account with **sudo** privileges using the name specified by the **USERNAME** variable. Default "**ubuntu**".
- Configure the initial password state for the new account:
    - If the server was configured for password authentication, the original, generated administrative password is moved from the **root** account to the new sudo account. The password for the **root** account is then locked.
    - If the server was configured for SSH key authentication, a blank password is set for the **root** account.  
- The **root** user's password is marked as expired so that it must be changed upon first login.
- The **authorized_keys** file from the **root** account is copied over to the sudo user if **COPY_AUTHORIZED_KEYS_FROM_ROOT** is set to true.
- Any keys defined in **OTHER_PUBLIC_KEYS_TO_ADD** are added to the **sudo** user’s **authorized_keys** file.
- Password-based SSH authentication is disabled for the **root** user.
- The **UFW firewall** is enabled with **SSH** connections permitted.

## LEMP

Optimized for PRODUCTION BY DEFAULT.

    - Ubuntu 18.04 (Recommended)
    - Nginx
      - Gzip for Nginx
    - PHP
      - 7.4
      - common PHP packages
      - PHP CLI (Production values)
      - PHP-FPM (Production values)
    - Databases (optional)
      - MariaDB (default) or MySQL
        - set a strong root password
        - (mysql_secure_installation)
      - MySQL 8
      - PostgreSQL
    - OPTIMIZATIONS
      - Setup unattended security upgrades
      - Firewall
        - SSH 22
        - HTTP 80
        - HTTPS 443
      - Fail2ban (https://www.fail2ban.org/wiki/index.php/Main_Page)
      - Timezone (UTC)
    - Included Software
      - Composer
      - NodeJS LTS (With Yarn, Bower, Grunt, and Gulp)
      - Letsencrypt Certbot (SSL)
    - Optional Software
      - Redis
      - Memcached
      - logrotate for Nginx logs

## Quick Guide

On your VPS run this:

```bash
curl -L https://raw.githubusercontent.com/rrpadilla/server-management/master/scripts/initial_server_setup.sh -o /tmp/initial_setup.sh && chmod +x /tmp/initial_setup.sh && bash /tmp/initial_setup.sh && rm /tmp/initial_setup.sh
```

If you have downloaded the script to your local computer, you can pass the script directly to SSH by typing:

```bash
ssh root@servers_public_IP "bash -s" -- < scripts/initial_server_setup.sh
```

Using a custom USERNAME **myusername**

```bash
ssh root@servers_public_IP "bash -s" -- < scripts/initial_server_setup.sh myusername
```
