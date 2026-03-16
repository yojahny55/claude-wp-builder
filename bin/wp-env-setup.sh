#!/usr/bin/env bash
# wp-env-setup.sh — System-level operations for WordPress local development
# Part of claude-wp-builder plugin
set -euo pipefail

VERSION="1.0.0"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Globals
JSON_OUTPUT=false
OS=""
PKG_MANAGER=""

##############################################################################
# Utility functions
##############################################################################

print_status() { [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${GREEN}[OK]${NC} $1"; }
print_warning() { [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${RED}[ERROR]${NC} $1"; }

detect_os() {
    if [[ -f /etc/fedora-release ]]; then
        OS="fedora"; PKG_MANAGER="dnf"
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"; PKG_MANAGER="dnf"
    elif [[ -f /etc/debian_version ]]; then
        if grep -qi ubuntu /etc/os-release 2>/dev/null; then
            OS="ubuntu"; PKG_MANAGER="apt"
        else
            OS="debian"; PKG_MANAGER="apt"
        fi
    elif [[ "$(uname)" == "Darwin" ]]; then
        OS="macos"; PKG_MANAGER="brew"
    else
        OS="unknown"; PKG_MANAGER="unknown"
    fi
}

get_version() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        "$cmd" --version 2>/dev/null | head -1 | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1 || echo "unknown"
    else
        echo ""
    fi
}

is_running() {
    local service="$1"
    if [[ "$OS" == "macos" ]]; then
        brew services list 2>/dev/null | grep "$service" | grep -q "started" && echo "true" || echo "false"
    else
        systemctl is-active "$service" &>/dev/null && echo "true" || echo "false"
    fi
}

##############################################################################
# detect — Detect available tools (no sudo required)
##############################################################################

cmd_detect() {
    detect_os

    # Web servers
    local nginx_installed=false nginx_version="" nginx_running=false
    local apache_installed=false apache_version="" apache_running=false
    local caddy_installed=false caddy_version="" caddy_running=false

    if command -v nginx &>/dev/null; then
        nginx_installed=true
        nginx_version=$(nginx -v 2>&1 | sed -n 's/.*\/\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' || echo "unknown")
        nginx_running=$(is_running nginx)
    fi

    if command -v httpd &>/dev/null || command -v apache2 &>/dev/null; then
        apache_installed=true
        apache_version=$( (httpd -v 2>/dev/null || apache2 -v 2>/dev/null) | head -1 | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p'  )
        [[ -z "$apache_version" ]] && apache_version="unknown"
        if [[ "$OS" == "fedora" ]] || [[ "$OS" == "rhel" ]]; then
            apache_running=$(is_running httpd)
        else
            apache_running=$(is_running apache2)
        fi
    fi

    if command -v caddy &>/dev/null; then
        caddy_installed=true
        caddy_version=$(get_version caddy)
        caddy_running=$(is_running caddy)
    fi

    # PHP
    local php_active="" php_versions="[]" php_extensions="[]"
    if command -v php &>/dev/null; then
        php_active=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "")
        php_extensions=$(php -m 2>/dev/null | grep -E '^(mysql|curl|mbstring|xml|gd|zip|intl|json|openssl|pdo)' | sort | awk '{printf "\"%s\",", $0}' | sed 's/,$//' || echo "")
        php_extensions="[${php_extensions}]"

        # Detect available PHP versions
        local versions=()
        if [[ "$OS" == "macos" ]]; then
            for v in $(brew list 2>/dev/null | sed -n 's/.*php@\([0-9.]*\)/\1/p' | sort -V); do versions+=("\"$v\""); done
        else
            for dir in /etc/php/*/; do
                [[ -d "$dir" ]] && versions+=("\"$(basename "$dir")\"")
            done
            # Also check alternatives
            if [[ ${#versions[@]} -eq 0 ]] && command -v php &>/dev/null; then
                versions+=("\"$php_active\"")
            fi
        fi
        php_versions="[$(IFS=,; echo "${versions[*]:-\"$php_active\"}")]"
    fi

    # Docker
    local docker_installed=false docker_version="" docker_compose=false
    if command -v docker &>/dev/null; then
        docker_installed=true
        docker_version=$(get_version docker)
        (docker compose version &>/dev/null || docker-compose --version &>/dev/null) && docker_compose=true
    fi

    # Dev tools
    local ddev_installed=false lando_installed=false wpenv_installed=false wpcli_installed=false
    local ddev_version="" lando_version="" wpcli_version=""

    command -v ddev &>/dev/null && ddev_installed=true && ddev_version=$(get_version ddev)
    command -v lando &>/dev/null && lando_installed=true && lando_version=$(get_version lando)
    command -v npx &>/dev/null && npx wp-env --version &>/dev/null 2>&1 && wpenv_installed=true
    if command -v wp &>/dev/null; then
        wpcli_installed=true
        wpcli_version=$(wp --version 2>/dev/null | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' || echo "unknown")
    fi

    # Database
    local mariadb_installed=false mariadb_version="" mariadb_running=false
    local mysql_installed=false mysql_version="" mysql_running=false

    if command -v mariadb &>/dev/null || (command -v mysql &>/dev/null && mysql --version 2>/dev/null | grep -qi mariadb); then
        mariadb_installed=true
        mariadb_version=$(mariadb --version 2>/dev/null | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1 || echo "unknown")
        mariadb_running=$(is_running mariadb || is_running mysql)
    elif command -v mysql &>/dev/null; then
        mysql_installed=true
        mysql_version=$(mysql --version 2>/dev/null | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -1 || echo "unknown")
        mysql_running=$(is_running mysql || is_running mysqld)
    fi

    # Output JSON
    cat <<JSONEOF
{
  "os": "$OS",
  "package_manager": "$PKG_MANAGER",
  "web_servers": {
    "nginx": { "installed": $nginx_installed, "version": "$nginx_version", "running": $nginx_running },
    "apache": { "installed": $apache_installed, "version": "$apache_version", "running": $apache_running },
    "caddy": { "installed": $caddy_installed, "version": "$caddy_version", "running": $caddy_running }
  },
  "php": {
    "versions": $php_versions,
    "active": "$php_active",
    "extensions": $php_extensions
  },
  "docker": {
    "installed": $docker_installed,
    "version": "$docker_version",
    "compose": $docker_compose
  },
  "tools": {
    "ddev": { "installed": $ddev_installed, "version": "$ddev_version" },
    "lando": { "installed": $lando_installed, "version": "$lando_version" },
    "wp-env": { "installed": $wpenv_installed },
    "wp-cli": { "installed": $wpcli_installed, "version": "$wpcli_version" }
  },
  "database": {
    "mariadb": { "installed": $mariadb_installed, "version": "$mariadb_version", "running": $mariadb_running },
    "mysql": { "installed": $mysql_installed, "version": "$mysql_version", "running": $mysql_running }
  }
}
JSONEOF
}

##############################################################################
# php-list — List available PHP versions (no sudo required)
##############################################################################

cmd_php_list() {
    detect_os
    local versions=()

    if [[ "$OS" == "macos" ]]; then
        for v in $(brew list 2>/dev/null | sed -n 's/.*php@\([0-9.]*\)/\1/p' | sort -V); do
            versions+=("$v")
        done
    else
        for dir in /etc/php/*/; do
            [[ -d "$dir" ]] && versions+=("$(basename "$dir")")
        done
    fi

    # Fallback to current version
    if [[ ${#versions[@]} -eq 0 ]] && command -v php &>/dev/null; then
        versions+=("$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')")
    fi

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '{"versions": ['; local first=true
        for v in "${versions[@]}"; do
            [[ "$first" == "true" ]] && first=false || printf ','
            printf '"%s"' "$v"
        done
        printf ']}\n'
    else
        echo "Available PHP versions:"
        for v in "${versions[@]}"; do echo "  - $v"; done
    fi
}

##############################################################################
# ssl-generate — Generate self-signed SSL cert (requires sudo)
##############################################################################

cmd_ssl_generate() {
    local domain=""
    for arg in "$@"; do
        case $arg in --domain=*) domain="${arg#*=}";; esac
    done

    [[ -z "$domain" ]] && { print_error "Usage: wp-env-setup.sh ssl-generate --domain=example.local.com"; exit 1; }

    detect_os
    local cert_dir="/etc/ssl/certs"
    local key_dir="/etc/ssl/private"

    print_status "Generating SSL certificate for $domain..."

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_dir/$domain.key" \
        -out "$cert_dir/$domain.crt" \
        -subj "/C=US/ST=Local/L=Local/O=Local Dev/OU=Local Dev/CN=$domain" 2>/dev/null

    # Trust the certificate on macOS
    if [[ "$OS" == "macos" ]]; then
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$cert_dir/$domain.crt"
    fi

    print_success "SSL certificate generated for $domain"

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{\"cert\": \"$cert_dir/$domain.crt\", \"key\": \"$key_dir/$domain.key\"}"
    fi
}

##############################################################################
# hosts-add / hosts-remove — Manage /etc/hosts entries (requires sudo)
##############################################################################

cmd_hosts_add() {
    local domain=""
    for arg in "$@"; do
        case $arg in --domain=*) domain="${arg#*=}";; esac
    done

    [[ -z "$domain" ]] && { print_error "Usage: wp-env-setup.sh hosts-add --domain=example.local.com"; exit 1; }

    if grep -q "127.0.0.1 $domain" /etc/hosts 2>/dev/null; then
        print_warning "$domain already exists in /etc/hosts"
    else
        echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts > /dev/null
        print_success "Added $domain to /etc/hosts"
    fi
}

cmd_hosts_remove() {
    local domain=""
    for arg in "$@"; do
        case $arg in --domain=*) domain="${arg#*=}";; esac
    done

    [[ -z "$domain" ]] && { print_error "Usage: wp-env-setup.sh hosts-remove --domain=example.local.com"; exit 1; }

    if grep -q "127.0.0.1 $domain" /etc/hosts 2>/dev/null; then
        sudo sed -i.bak "/127.0.0.1 $domain/d" /etc/hosts
        print_success "Removed $domain from /etc/hosts"
    else
        print_warning "$domain not found in /etc/hosts"
    fi
}

##############################################################################
# permissions — Set WordPress file/folder permissions (requires sudo)
##############################################################################

cmd_permissions() {
    local path="" web_user=""
    for arg in "$@"; do
        case $arg in
            --path=*) path="${arg#*=}";;
            --web-user=*) web_user="${arg#*=}";;
        esac
    done

    [[ -z "$path" ]] && { print_error "Usage: wp-env-setup.sh permissions --path=/var/www/html/site [--web-user=nginx]"; exit 1; }
    [[ ! -d "$path" ]] && { print_error "Directory not found: $path"; exit 1; }

    detect_os
    if [[ -z "$web_user" ]]; then
        case "$OS" in
            fedora|rhel) web_user="nginx";;
            ubuntu|debian) web_user="www-data";;
            macos) web_user="$(whoami)";;
            *) web_user="www-data";;
        esac
    fi

    print_status "Setting permissions for $path (web user: $web_user)..."

    sudo chown -R "$web_user:$web_user" "$path"
    sudo find "$path" -type d -exec chmod 755 {} \;
    sudo find "$path" -type f -exec chmod 644 {} \;

    # Writable directories
    for dir in uploads plugins themes cache; do
        [[ -d "$path/wp-content/$dir" ]] && sudo chmod 775 "$path/wp-content/$dir"
    done
    mkdir -p "$path/wp-content/uploads"
    sudo chmod 775 "$path/wp-content/uploads"

    # Add current user to web group
    local current_user
    current_user=$(whoami)
    if [[ "$OS" != "macos" ]] && [[ "$current_user" != "$web_user" ]]; then
        sudo usermod -a -G "$web_user" "$current_user" 2>/dev/null || true
    fi

    print_success "Permissions set for $path"
}

##############################################################################
# php-install — Install PHP version (requires sudo)
##############################################################################

cmd_php_install() {
    local version=""
    for arg in "$@"; do
        case $arg in --version=*) version="${arg#*=}";; esac
    done

    [[ -z "$version" ]] && { print_error "Usage: wp-env-setup.sh php-install --version=8.3"; exit 1; }

    detect_os
    print_status "Installing PHP $version..."

    local extensions="cli fpm mysql curl mbstring xml gd zip intl"

    case "$OS" in
        fedora|rhel)
            sudo dnf install -y "php${version//./}" $(echo "$extensions" | sed "s/[^ ]*/php${version//./}-&/g") || {
                # Try remi repo format
                sudo dnf install -y "php$version" $(echo "$extensions" | sed "s/[^ ]*/php$version-php-&/g")
            }
            ;;
        ubuntu|debian)
            # Add ondrej PPA if not present
            if ! ls /etc/apt/sources.list.d/*ondrej* &>/dev/null; then
                sudo add-apt-repository -y ppa:ondrej/php 2>/dev/null || true
                sudo apt update
            fi
            sudo apt install -y "php$version" $(echo "$extensions" | sed "s/[^ ]*/php$version-&/g")
            ;;
        macos)
            brew install "php@$version"
            brew link "php@$version" --force
            ;;
        *)
            print_error "Unsupported OS for PHP installation: $OS"
            exit 1
            ;;
    esac

    print_success "PHP $version installed"
}

##############################################################################
# service-reload — Reload web server (requires sudo)
##############################################################################

cmd_service_reload() {
    local service=""
    for arg in "$@"; do
        case $arg in --service=*) service="${arg#*=}";; esac
    done

    [[ -z "$service" ]] && { print_error "Usage: wp-env-setup.sh service-reload --service=nginx"; exit 1; }

    detect_os
    print_status "Reloading $service..."

    if [[ "$OS" == "macos" ]]; then
        brew services restart "$service"
    else
        local svc_name="$service"
        [[ "$service" == "apache" && ("$OS" == "fedora" || "$OS" == "rhel") ]] && svc_name="httpd"
        [[ "$service" == "apache" && ("$OS" == "ubuntu" || "$OS" == "debian") ]] && svc_name="apache2"
        sudo systemctl reload "$svc_name" 2>/dev/null || sudo systemctl restart "$svc_name"
    fi

    print_success "$service reloaded"
}

##############################################################################
# native-setup — Full native vhost + SSL + hosts (requires sudo)
##############################################################################

cmd_native_setup() {
    local domain="" document_root="" web_server="" template_dir=""
    local ssl=true
    for arg in "$@"; do
        case $arg in
            --domain=*) domain="${arg#*=}";;
            --document-root=*) document_root="${arg#*=}";;
            --web-server=*) web_server="${arg#*=}";;
            --template-dir=*) template_dir="${arg#*=}";;
            --no-ssl) ssl=false;;
        esac
    done

    [[ -z "$domain" || -z "$document_root" || -z "$web_server" ]] && {
        print_error "Usage: wp-env-setup.sh native-setup --domain=x --document-root=x --web-server=nginx|apache|caddy [--template-dir=x] [--no-ssl]"
        exit 1
    }

    detect_os

    # SSL
    if [[ "$ssl" == "true" && "$web_server" != "caddy" ]]; then
        cmd_ssl_generate --domain="$domain"
    fi

    # Hosts
    cmd_hosts_add --domain="$domain"

    # Vhost config (generated by Claude from templates — this just installs it)
    print_status "Web server config should be generated by Claude from templates and placed in the appropriate directory."
    print_status "For nginx: /etc/nginx/conf.d/$domain.conf"
    print_status "For apache: /etc/httpd/conf.d/$domain.conf or /etc/apache2/sites-available/$domain.conf"
    print_status "For caddy: append to /etc/caddy/Caddyfile"

    # Reload
    cmd_service_reload --service="$web_server"
}

##############################################################################
# native-remove — Remove vhost + SSL + hosts (requires sudo)
##############################################################################

cmd_native_remove() {
    local domain="" web_server=""
    for arg in "$@"; do
        case $arg in
            --domain=*) domain="${arg#*=}";;
            --web-server=*) web_server="${arg#*=}";;
        esac
    done

    [[ -z "$domain" ]] && { print_error "Usage: wp-env-setup.sh native-remove --domain=x [--web-server=nginx]"; exit 1; }

    detect_os

    # Remove SSL certs
    sudo rm -f "/etc/ssl/certs/$domain.crt" "/etc/ssl/private/$domain.key"
    print_success "Removed SSL certificates for $domain"

    # Remove hosts entry
    cmd_hosts_remove --domain="$domain"

    # Remove vhost (best effort)
    sudo rm -f "/etc/nginx/conf.d/$domain.conf"
    sudo rm -f "/etc/httpd/conf.d/$domain.conf"
    sudo rm -f "/etc/apache2/sites-available/$domain.conf"
    sudo rm -f "/etc/apache2/sites-enabled/$domain.conf"

    print_success "Removed native setup for $domain"

    [[ -n "$web_server" ]] && cmd_service_reload --service="$web_server"
}

##############################################################################
# Main dispatcher
##############################################################################

show_usage() {
    cat <<EOF
wp-env-setup.sh v$VERSION — System-level operations for WordPress local development

Usage: wp-env-setup.sh <command> [options]

Commands (no sudo):
  detect                Detect available tools, output JSON
  php-list              List available PHP versions

Commands (requires sudo):
  native-setup          Install vhost + SSL + hosts entry
  native-remove         Remove vhost, SSL cert, hosts entry
  permissions           Set WordPress file/folder permissions
  php-install           Install PHP version
  ssl-generate          Generate self-signed SSL certificate
  hosts-add             Add /etc/hosts entry
  hosts-remove          Remove /etc/hosts entry
  service-reload        Reload web server

Global options:
  --json                Machine-readable JSON output

EOF
}

main() {
    # Parse global flags
    local args=()
    for arg in "$@"; do
        case $arg in
            --json) JSON_OUTPUT=true;;
            *) args+=("$arg");;
        esac
    done

    [[ ${#args[@]} -eq 0 ]] && { show_usage; exit 1; }

    local cmd="${args[0]}"
    local remaining=("${args[@]:1}")

    case "$cmd" in
        detect)         cmd_detect "${remaining[@]:-}";;
        php-list)       cmd_php_list "${remaining[@]:-}";;
        ssl-generate)   cmd_ssl_generate "${remaining[@]}";;
        hosts-add)      cmd_hosts_add "${remaining[@]}";;
        hosts-remove)   cmd_hosts_remove "${remaining[@]}";;
        permissions)    cmd_permissions "${remaining[@]}";;
        php-install)    cmd_php_install "${remaining[@]}";;
        service-reload) cmd_service_reload "${remaining[@]}";;
        native-setup)   cmd_native_setup "${remaining[@]}";;
        native-remove)  cmd_native_remove "${remaining[@]}";;
        -h|--help|help) show_usage;;
        *)              print_error "Unknown command: $cmd"; show_usage; exit 1;;
    esac
}

main "$@"
