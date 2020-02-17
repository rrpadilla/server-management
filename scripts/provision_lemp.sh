#!/bin/bash

set -ueo pipefail

########################
###     CHECK OS     ###
########################
checkOS="$(uname -v)"
echo -e " CHECKING OS Kernel VERSION: $checkOS"
if [[ ! $checkOS == *"Ubuntu"* ]];
    then
        echo -e " You are not using Ubuntu!!!"
        exit 1
fi

########################
### SCRIPT VARIABLES ###
########################
USERNAME="ubuntu"
PRODUCTIONVALUES=true
default_php_version="7.4"
default_database="mysql"
PHPVERSION="$default_php_version"
MULTIPHPVERSION=()
DB="$default_database"
phpSupported=("7.4" "7.3" "7.2" "7.1" "7.0" "5.6")
dbSupported=("none" "mariadb" "mysql" "postgresql")
#allOptions=()

#########################
# The command line help #
#########################
function help() {
    printf "%s\n" >&2 "Usage: $0 [options]" \
    "" \
    "Provision your LEMP Server" \
    "" \
    "Common commands:" \
    "" \
    " $ $0 --php 7.2 --db none" \
    "" \
    " To install PHP version 7.2 and no database." \
    "" \
    " $ $0 --db postgresql" \
    "" \
    " To install default PHP version ($default_php_version) and PostgreSQL database." \
    "" \
    "Usage: $0 [options]" \
    "" \
    "Arguments:" \
    "" \
    " -h --help    Print this usage information." \
    " --php VALUE  To install custom PHP version. Default ($default_php_version)." \
    " --db VALUE   Install a database [none, mariadb, mysql, postgresql]. Default ($default_database)." \
    " --dev        To use development values. By default using production values." \
    ""
}

#########################
# Print error #
#########################
function error() {
  echo -e "Error: $1 \n" >&2
  help
  exit 1
}

function check_php_option() {
    local foundedPhp=""
    local v="$1"
    local tmp="${v/./_}" # replace "." with "_" -> "7.2" = "7_2"
    local tmp1=""
    for i in "${phpSupported[@]}"; do
        tmp1="${i/./_}"
        if [[ "$tmp" = "$tmp1" ]]; then
            foundedPhp="$i"
            break
        fi
    done
    echo "$foundedPhp"
}

function check_db_option() {
    local foundedDB=""
    local v="$1"
    for i in "${dbSupported[@]}"; do
        if [[ "$v" = "$i" ]]; then
            foundedDB="$i"
            break
        fi
    done
    echo "$foundedDB"
}

##############################
### INITIALIZING VARIABLES ###
##############################
while [ $# -gt 0 ]
do
    case "$1" in
        "--help"|"-h")
            help
            exit 0
            ;;
        "--php")
            [ -z "$2" ] && error "Must supply a valid PHP VERSION to the --php option."
            [ -z "$(check_php_option "$2")" ] && error "Invalid PHP VERSION ($2) provided."
            PHPVERSION="$2"
            MULTIPHPVERSION+=("$PHPVERSION")
            shift;;
        "--multiphp")
            [ -z "$2" ] && error "Must supply a valid value to the --multiphp option."
            tmpArr=("$2")
            for i in "${tmpArr[@]}"; do
                [ -z "$(check_php_option "$i")" ] && error "Invalid PHP VERSION ($i) provided."
                MULTIPHPVERSION+=("$i")
            done
            shift;;
        "--db")
            [ -z "$2" ] && error "Must supply a valid database to the --db option."
            [ -z "$(check_db_option "$2")" ] && error "Invalid database ($2) provided."
            DB="$2"
            shift;;
        "--dev")
            PRODUCTIONVALUES=false
            shift;;
        -*)
            error "Invalid argument provided: $1"
            ;;
        *)
            break;;	# terminate while loop
    esac
    shift
done

echo -e "VARIABLES TO USE: \n PHP $PHPVERSION \n DB $DB."
#echo -e " PHP VERSIONS TO INSTALL: ${MULTIPHPVERSION[@]}"
#echo -e " The array contains ${#MULTIPHPVERSION[@]} elements"

######################################################
####              INSTALL PACKAGES NOW           #####
######################################################

function main() {
    export DEBIAN_FRONTEND=noninteractive

    the_first
    the_firewall
    the_basics
    the_nginx
    the_php
    the_database_install
    the_unattended_security_upgrades
    the_cleanup
}

function the_first() {
    # Update Package List
    apt-get update

    # Update System Packages
    apt-get upgrade -y

    # Force Locale
    echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
    locale-gen en_US.UTF-8

    # Set Default Timezone (UTC)
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime

    # Update system clock
    timedatectl set-ntp on
}

function the_firewall() {
    # Fail2ban and Firewall
    apt-get install -y fail2ban ufw

    ufw allow 22        # SSH. Initital setup installed this too.
    ufw allow 80        # HTTP
    ufw allow 443       # HTTPS
    ufw --force enable  # Enable Firewall
}

function the_basics() {
    # Add some PPAs to stay current
    apt-get install -y software-properties-common
    apt-add-repository ppa:nginx/stable -y
    apt-add-repository ppa:ondrej/php -y
    ## apt-add-repository ppa:chris-lea/redis-server -y

    # Update Package List
    apt-get update

    # Install Some Basic Packages
    sudo apt-get install -y git curl wget zip unzip libmcrypt4 libpcre3-dev imagemagick
}

function the_nginx() {
    # Install Nginx
    sudo apt-get install -y nginx

    # Add user to the webserver user group
    usermod -a -G www-data $USERNAME

    # Set The Nginx User
    sed -i "s/user www-data;/user $USERNAME;/" /etc/nginx/nginx.conf
    # Tweak Nginx settings
    sed -i "s/worker_processes.*/worker_processes auto;/" /etc/nginx/nginx.conf
    sed -i "s/# multi_accept.*/multi_accept on;/" /etc/nginx/nginx.conf
    sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 128;/" /etc/nginx/nginx.conf
    sed -i "s/# server_tokens off/server_tokens off/" /etc/nginx/nginx.conf

    the_gzip_for_nginx
}

function the_gzip_for_nginx() {
    # Configure Gzip for Nginx
    cat > /etc/nginx/conf.d/gzip.conf << EOF
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_vary on;

gzip_types
application/atom+xml
application/javascript
application/json
application/rss+xml
application/vnd.ms-fontobject
application/x-web-app-manifest+json
application/xhtml+xml
application/xml
font/otf
font/ttf
image/svg+xml
image/x-icon
text/css
text/plain;
EOF
}

function the_php() {
    # Install Generic PHP packages
    apt-get install -y --allow-change-held-packages \
    php-imagick php-memcached php-redis

    # Install PHP (PHP-FPM, PHP-CLI and extensions)
    the_php_generator_config "$PHPVERSION"
    the_php_generator_cli "$PHPVERSION"
    the_php_generator_fpm "$PHPVERSION"

    # Install MORE PHP (PHP-FPM, PHP-CLI and extensions)
    if [ "${#MULTIPHPVERSION[@]}" -gt 1 ]
        then
            for i in "${MULTIPHPVERSION[@]}"; do
                the_php_generator_config "$i"
                the_php_generator_cli "$i"
                the_php_generator_fpm "$i"
            done
    fi

    # Set default PHP VERSION
    update-alternatives --set php /usr/bin/php"$PHPVERSION"
}

function the_php_generator_config() {
    local phpVersion="$1"
    if [ -z "$phpVersion" ]; then
        # Install PHP (PHP-FPM, PHP-CLI and extensions)
        apt-get install -y --allow-change-held-packages \
        php"$phpVersion" php"$phpVersion"-bcmath php"$phpVersion"-bz2 php"$phpVersion"-cgi php"$phpVersion"-cli php"$phpVersion"-common php"$phpVersion"-curl php"$phpVersion"-dba php"$phpVersion"-dev \
        php"$phpVersion"-enchant php"$phpVersion"-fpm php"$phpVersion"-gd php"$phpVersion"-gmp php"$phpVersion"-imap php"$phpVersion"-interbase php"$phpVersion"-intl php"$phpVersion"-json php"$phpVersion"-ldap \
        php"$phpVersion"-mbstring php"$phpVersion"-mysql php"$phpVersion"-odbc php"$phpVersion"-opcache php"$phpVersion"-pgsql php"$phpVersion"-phpdbg php"$phpVersion"-pspell php"$phpVersion"-readline \
        php"$phpVersion"-snmp php"$phpVersion"-soap php"$phpVersion"-sqlite3 php"$phpVersion"-sybase php"$phpVersion"-tidy php"$phpVersion"-xml php"$phpVersion"-xmlrpc php"$phpVersion"-xsl php"$phpVersion"-zip
    fi
}

function the_php_generator_cli() {
    local phpVersion="$1"
    if [ -z "$phpVersion" ]; then
        # Set Some PHP CLI Settings
        sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/"$phpVersion"/cli/php.ini
        sed -i "s/display_errors = .*/display_errors = On/" /etc/php/"$phpVersion"/cli/php.ini
        sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/"$phpVersion"/cli/php.ini
        sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/"$phpVersion"/cli/php.ini
    fi
}

function the_php_generator_fpm() {
    local phpVersion="$1"
    if [ -z "$phpVersion" ]; then
        # Tweak PHP-FPM settings
        if [ "$PRODUCTIONVALUES" = true ];
            then
                ## see: https://github.com/php/php-src/blob/master/php.ini-production
                ## Suppressing PHP error output here by setting these options to production values
                sed -i "s/error_reporting = .*/error_reporting = E_ALL \& ~E_DEPRECATED \& ~E_STRICT/" /etc/php/"$phpVersion"/fpm/php.ini
                sed -i "s/display_errors = .*/display_errors = Off/" /etc/php/"$phpVersion"/fpm/php.ini
                sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/"$phpVersion"/fpm/php.ini
                sed -i "s/upload_max_filesize = .*/upload_max_filesize = 256M/" /etc/php/"$phpVersion"/fpm/php.ini
                sed -i "s/post_max_size = .*/post_max_size = 256M/" /etc/php/"$phpVersion"/fpm/php.ini
                sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/"$phpVersion"/fpm/php.ini

                ## Tune PHP-FPM pool settings
                sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/;request_terminate_timeout.*/request_terminate_timeout = 60/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/pm\.max_children.*/pm.max_children = 70/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/pm\.start_servers.*/pm.start_servers = 20/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/pm\.min_spare_servers.*/pm.min_spare_servers = 20/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/pm\.max_spare_servers.*/pm.max_spare_servers = 35/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/;pm\.max_requests.*/pm.max_requests = 500/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                # Set The PHP-FPM User
                sed -i "s/user = www-data/user = $USERNAME/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/group = www-data/group = $USERNAME/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/listen\.owner.*/listen.owner = $USERNAME/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
                sed -i "s/listen\.group.*/listen.group = $USERNAME/" /etc/php/"$phpVersion"/fpm/pool.d/www.conf
        fi
    fi
}

function the_database_install() {
    # Install MariaDB (MySQL) and set a strong root password
    the_mysql
}

function the_mysql() {
    echo -e " Installing MySQL"
    local MYSQLPASS=""
    MYSQLPASS=$(openssl rand -base64 32)

    if [ ! -d /home/"$USERNAME"/.provisioner/configs ]; 
        then
            echo -e ".provisioner/configs DOES NOT EXIST!"
            mkdir /home/"$USERNAME"/.provisioner/configs
        else
            echo -e ".provisioner/configs EXISTS!"
    fi

    echo "$MYSQLPASS" > /home/"$USERNAME"/.provisioner/configs/mysqlpass.txt

    echo "mysql-server mysql-server/root_password password $MYSQLPASS" | sudo debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQLPASS" | sudo debconf-set-selections

    apt-get install -y mysql-server
    mysql_secure_installation
}

#function the_mariadb() {
#    ## TODO
#}

#function the_postgresql() {
#    ## TODO
#}

function the_ssl() {
    # Install Letsencrypt Certbot
    add-apt-repository ppa:certbot/certbot -y
    apt-get update
    apt-get install -y python-certbot-nginx
}

function the_optionals() {
    # Installing the latest NodeJS LTS
    the_nodejs

    # Install Composer
    the_composer
}

function the_nodejs() {
    # Installing the latest NodeJS LTS
    curl -sL https://deb.nodesource.com/setup_12.x | bash -
    apt-get update
    apt-get install -y nodejs
    /usr/bin/npm install -g npm
    /usr/bin/npm install -g gulp-cli
    /usr/bin/npm install -g bower
    /usr/bin/npm install -g yarn
    /usr/bin/npm install -g grunt-cli
}

function the_redis() {
    # Install Redis
    apt-get install redis-server -y
    # Set systemd for supervised and restart Redis
    sed -i "s/supervised.*/supervised systemd/" /etc/redis/redis.conf
    systemctl restart redis.service

    # Install Redis, Memcached, & Beanstalk
    #apt-get install -y redis-server memcached beanstalkd
    #systemctl enable redis-server
    #service redis-server start
}

function the_supervisor() {
    # Install Redis
    apt-get install supervisor -y
    # Configure Supervisor
    systemctl enable supervisor.service
    service supervisor start
}

function the_composer() {
    # Install Composer
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
}

function the_unattended_security_upgrades() {
    # Automatic Updates
    ## The unattended-upgrades package can be used 
    ## to automatically install updated packages, 
    ## and can be configured to update all packages 
    ## or just install security updates
    ## see: https://help.ubuntu.com/lts/serverguide/automatic-updates.html
    sudo apt-get install unattended-upgrades -y

    cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "Ubuntu bionic-security";
};
Unattended-Upgrade::Package-Blacklist {
    //
};
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
}

function the_cleanup() {
    # Clean Up
    apt-get -y autoremove
    apt-get -y clean
}

# leave this last to prevent any partial executions
main
