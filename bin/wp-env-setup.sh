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

print_status() { if [[ "$JSON_OUTPUT" == "false" ]]; then echo -e "${BLUE}[INFO]${NC} $1"; fi; }
print_success() { if [[ "$JSON_OUTPUT" == "false" ]]; then echo -e "${GREEN}[OK]${NC} $1"; fi; }
print_warning() { if [[ "$JSON_OUTPUT" == "false" ]]; then echo -e "${YELLOW}[WARN]${NC} $1"; fi; }
print_error() { if [[ "$JSON_OUTPUT" == "false" ]]; then echo -e "${RED}[ERROR]${NC} $1"; fi; }

# A domain ends up in sudo rm paths, /etc/hosts, a sed regex and an openssl
# subject, so it is checked before any command acts on it: lowercase letters,
# digits, dots and hyphens only, starting and ending alphanumeric. That rules out
# "/", "..", spaces, regex metacharacters and shell syntax in one place.
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$ ]]; then
        print_error "Invalid domain '$domain': use lowercase letters, digits, dots and hyphens only"
        exit 1
    fi
}

# The RHEL-style Apache layout is chosen by whether this directory exists. Overridable so a
# test can select the layout; it only decides WHICH fixed /etc path is written, never where.
HTTPD_LAYOUT_PROBE="${WP_ENV_HTTPD_LAYOUT_PROBE:-/etc/httpd/conf.d}"

# Web servers native-setup knows how to configure.
validate_web_server() {
    case "$1" in
        nginx|apache|caddy) ;;
        *) print_error "Unknown web server '$1': use nginx, apache or caddy"; exit 1;;
    esac
}

# Root writes a vhost to --dest, so it must sit under a web server's config tree, with no ".."
# component that could climb out of it. Shared by vhost-install and native-setup.
validate_vhost_dest() {
    local dest="$1"
    if [[ ! "$dest" =~ ^/etc/(nginx|httpd|apache2|caddy)/[^[:space:]]+$ || "$dest" =~ (^|/)\.\.(/|$) ]]; then
        print_error "Refusing --dest outside /etc/{nginx,httpd,apache2,caddy}/: $dest"
        exit 1
    fi
}

# hosts file path; overridable so tests never touch the real /etc/hosts
HOSTS_FILE="${WP_ENV_HOSTS_FILE:-/etc/hosts}"

# True when HOSTS_FILE has a 127.0.0.1 line for exactly this domain (anchored,
# so foo.local does not match foo.local.es or myfoo.local). Domain is already
# validated, so only the dots need escaping.
hosts_has_domain() {
    local escaped="${1//./\\.}"
    grep -Eq "^127\.0\.0\.1[[:space:]]+${escaped}([[:space:]]|\$)" "$HOSTS_FILE" 2>/dev/null
}

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
    validate_domain "$domain"

    detect_os
    local cert_dir="/etc/ssl/certs"
    local key_dir="/etc/ssl/private"

    print_status "Generating SSL certificate for $domain..."

    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_dir/$domain.key" \
        -out "$cert_dir/$domain.crt" \
        -subj "/C=US/ST=Local/L=Local/O=Local Dev/OU=Local Dev/CN=$domain" \
        -addext "subjectAltName=DNS:$domain"

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
    validate_domain "$domain"

    if hosts_has_domain "$domain"; then
        print_warning "$domain already exists in $HOSTS_FILE"
    else
        echo "127.0.0.1 $domain" | sudo tee -a "$HOSTS_FILE" > /dev/null
        print_success "Added $domain to $HOSTS_FILE"
    fi
}

cmd_hosts_remove() {
    local domain=""
    for arg in "$@"; do
        case $arg in --domain=*) domain="${arg#*=}";; esac
    done

    [[ -z "$domain" ]] && { print_error "Usage: wp-env-setup.sh hosts-remove --domain=example.local.com"; exit 1; }
    validate_domain "$domain"

    if hosts_has_domain "$domain"; then
        local escaped="${domain//./\\.}"
        sudo sed -i.bak -E "/^127\.0\.0\.1[[:space:]]+${escaped}([[:space:]]|\$)/d" "$HOSTS_FILE"
        print_success "Removed $domain from $HOSTS_FILE"
    else
        print_warning "$domain not found in $HOSTS_FILE"
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
    path=$(realpath -- "$path") || { print_error "Cannot resolve path: $path"; exit 1; }
    if [[ "$path" == "/" || "$path" == "${HOME:-}" || "$path" == "$(realpath -- "${HOME:-/nonexistent}" 2>/dev/null || true)" ]]; then
        print_error "Refusing to change permissions on $path"
        exit 1
    fi
    if [[ ! -f "$path/wp-config.php" && ! -d "$path/wp-content" ]]; then
        print_error "Not a WordPress directory (no wp-config.php or wp-content/): $path"
        exit 1
    fi
    if [[ -n "$web_user" && ! "$web_user" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        print_error "Invalid --web-user '$web_user'"
        exit 1
    fi

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

    # .git and node_modules are pruned: their ownership and executable bits are not ours to reset.
    # chown without -R still follows a symlink given as an operand, so only real directories and
    # files are listed (a symlink to /etc/shadow is skipped) and -h keeps it off any link that races in.
    # -execdir applies each change relative to the directory find is visiting, which closes the race on
    # intermediate directories: an ancestor swapped for a symlink after the listing is not followed.
    # GNU chmod has no -h, so a leaf swapped for a symlink between find's stat and the exec remains a
    # narrow residual risk; the type test and the change are one pass, which keeps that window small.
    # -execdir refuses to run when PATH holds a relative or empty entry, and sudo may keep the caller's
    # PATH, so find runs under a fixed absolute PATH.
    local safe_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    sudo env PATH="$safe_path" find "$path" \( -name .git -o -name node_modules \) -prune -o \( -type d -o -type f \) -execdir chown -h "$web_user:$web_user" {} +
    sudo env PATH="$safe_path" find "$path" \( -name .git -o -name node_modules \) -prune -o -type d -execdir chmod 755 {} +
    sudo env PATH="$safe_path" find "$path" \( -name .git -o -name node_modules \) -prune -o -type f -execdir chmod 644 {} +

    # Writable directories: type check and chmod in one find pass; a symlink is excluded by type.
    mkdir -p "$path/wp-content/uploads"
    for dir in uploads plugins themes cache; do
        if [[ -L "$path/wp-content/$dir" ]]; then
            print_warning "wp-content/$dir is a symlink; leaving its permissions alone"
        else
            sudo env PATH="$safe_path" find "$path/wp-content" -mindepth 1 -maxdepth 1 -name "$dir" -type d -execdir chmod 775 {} +
        fi
    done

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
            # shellcheck disable=SC2046 # word splitting is the point: one package argument per extension
            sudo dnf install -y "php${version//./}" $(echo "$extensions" | sed "s/[^ ]*/php${version//./}-&/g") || {
                # Try remi repo format
                # shellcheck disable=SC2046 # word splitting is the point: one package argument per extension
                sudo dnf install -y "php$version" $(echo "$extensions" | sed "s/[^ ]*/php$version-php-&/g")
            }
            ;;
        ubuntu|debian)
            # Add ondrej PPA if not present
            if ! ls /etc/apt/sources.list.d/*ondrej* &>/dev/null; then
                sudo add-apt-repository -y ppa:ondrej/php 2>/dev/null || true
                sudo apt update
            fi
            # shellcheck disable=SC2046 # word splitting is the point: one package argument per extension
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

    case "$service" in
        nginx|apache|apache2|httpd|caddy|php-fpm*|php[0-9]*-fpm) ;;
        *) print_error "Refusing to reload unknown service '$service'"; exit 1;;
    esac

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
# vhost-install — Install a vhost config file with correct ownership,
# permissions, and SELinux context (requires sudo)
#
# This is the safe way to deploy a generated config from a staging location
# (typically /tmp/x.conf written by Claude) into the web server's conf.d
# directory. On Fedora/RHEL/CentOS with SELinux enforcing, files moved from
# /tmp inherit the user_tmp_t label and nginx/apache (running as confined
# domains) cannot read them — reload fails with "(13: Permission denied)".
# This command runs restorecon to apply the correct httpd_config_t label.
##############################################################################

cmd_vhost_install() {
    local src="" dest=""
    for arg in "$@"; do
        case $arg in
            --src=*)  src="${arg#*=}";;
            --dest=*) dest="${arg#*=}";;
        esac
    done

    [[ -z "$src" || -z "$dest" ]] && {
        print_error "Usage: wp-env-setup.sh vhost-install --src=/tmp/x.conf --dest=/etc/nginx/conf.d/x.conf"
        exit 1
    }
    [[ ! -f "$src" ]] && { print_error "Source file not found: $src"; exit 1; }
    validate_vhost_dest "$dest"

    # Install atomically with correct mode + owner. `install` is preferable to
    # `mv`/`cp` because it sets all three in one call without race windows.
    sudo install -m 644 -o root -g root "$src" "$dest" || {
        print_error "Failed to install $src → $dest"
        exit 1
    }

    # Fix SELinux context if SELinux is enforcing.
    # On Debian/Ubuntu this is a no-op (no getenforce/restorecon).
    if command -v getenforce >/dev/null 2>&1 && command -v restorecon >/dev/null 2>&1; then
        local mode
        mode=$(getenforce 2>/dev/null || echo "Disabled")
        if [[ "$mode" != "Disabled" ]]; then
            sudo restorecon -F "$dest" >/dev/null 2>&1 || true
            print_status "Applied SELinux context to $dest (enforcing mode: $mode)"
        fi
    fi

    print_success "Installed vhost: $dest"

    # Clean up source if it was staged in /tmp
    if [[ "$src" == /tmp/* ]]; then
        rm -f "$src" 2>/dev/null || true
    fi
}

##############################################################################
# native-setup — Full native vhost + SSL + hosts (requires sudo)
##############################################################################

cmd_native_setup() {
    local domain="" document_root="" web_server="" template_dir="" vhost_src=""
    local ssl=true
    for arg in "$@"; do
        case $arg in
            --domain=*) domain="${arg#*=}";;
            --document-root=*) document_root="${arg#*=}";;
            --web-server=*) web_server="${arg#*=}";;
            --template-dir=*) template_dir="${arg#*=}";;
            --vhost-src=*) vhost_src="${arg#*=}";;
            --no-ssl) ssl=false;;
        esac
    done

    [[ -z "$domain" || -z "$document_root" || -z "$web_server" ]] && {
        print_error "Usage: wp-env-setup.sh native-setup --domain=x --document-root=x --web-server=nginx|apache|caddy [--vhost-src=/tmp/x.conf] [--template-dir=x] [--no-ssl]"
        exit 1
    }
    validate_domain "$domain"
    validate_web_server "$web_server"

    detect_os

    # Work out and validate the vhost destination before anything runs under sudo, so a refusal
    # leaves no certificate and no hosts entry behind.
    local dest="" debian_apache=false
    if [[ -n "$vhost_src" ]]; then
        case "$web_server" in
            nginx)  dest="/etc/nginx/conf.d/$domain.conf";;
            apache)
                if [[ -d "$HTTPD_LAYOUT_PROBE" ]]; then
                    dest="/etc/httpd/conf.d/$domain.conf"
                else
                    dest="/etc/apache2/sites-available/$domain.conf"
                    debian_apache=true
                fi
                ;;
            caddy)
                print_error "--vhost-src is not supported for caddy (configs append to Caddyfile). Install manually."
                return 1
                ;;
        esac
        validate_vhost_dest "$dest"
    fi

    # SSL
    if [[ "$ssl" == "true" && "$web_server" != "caddy" ]]; then
        cmd_ssl_generate --domain="$domain"
    fi

    # Hosts
    cmd_hosts_add --domain="$domain"

    # Vhost config — if --vhost-src is provided, install it; otherwise print
    # guidance for Claude to write the config and then call vhost-install.
    if [[ -n "$vhost_src" ]]; then
        cmd_vhost_install --src="$vhost_src" --dest="$dest"
        # Debian keeps vhosts in sites-available; they are served only once enabled.
        if [[ "$debian_apache" == "true" ]]; then
            sudo a2enmod ssl proxy_fcgi rewrite
            sudo a2ensite "$domain"
        fi
    else
        print_status "Web server config should be generated by Claude from templates and placed in the appropriate directory."
        print_status "Tip: use 'wp-env-setup.sh vhost-install --src=/tmp/x.conf --dest=...' to install with correct SELinux context."
        print_status "For nginx: /etc/nginx/conf.d/$domain.conf"
        print_status "For apache: /etc/httpd/conf.d/$domain.conf or /etc/apache2/sites-available/$domain.conf"
        print_status "For caddy: append to /etc/caddy/Caddyfile"
    fi

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
    validate_domain "$domain"

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
  vhost-install         Install a generated vhost config with correct mode,
                        owner, and SELinux context (restorecon)
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
        vhost-install)  cmd_vhost_install "${remaining[@]}";;
        -h|--help|help) show_usage;;
        *)              print_error "Unknown command: $cmd"; show_usage; exit 1;;
    esac
}

main "$@"
