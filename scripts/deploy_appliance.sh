#!/usr/bin/env bash
# Deploy the Ubuntu 24.04 network appliance configuration from this repository.
# Review interface/subnet settings and confirm console/out-of-band access before use.
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly BACKUP_ROOT="/var/backups/network-appliance"
readonly NETPLAN_FILE="/etc/netplan/99-network-appliance-lan.yaml"

WAN_IF="${WAN_IF:-ens18}"
LAN_IF="${LAN_IF:-ens19}"
LAN_SUBNET="${LAN_SUBNET:-10.115.0.0/24}"
LAN_ADDRESS="${LAN_ADDRESS:-10.115.0.250/24}"
SSH_PORT="${SSH_PORT:-2222}"
ASSUME_YES=0

usage() {
  cat <<'USAGE'
Usage: sudo ./scripts/deploy_appliance.sh [--yes]

Deploys this repository's SSH, BIND9, Kea DHCPv4, and UFW/NAT configuration.
Review WAN_IF, LAN_IF, LAN_SUBNET, LAN_ADDRESS, and SSH_PORT before running, e.g.:
  sudo WAN_IF=ens18 LAN_IF=ens19 LAN_SUBNET=10.115.0.0/24 LAN_ADDRESS=10.115.0.250/24 ./scripts/deploy_appliance.sh
The script configures the LAN address persistently with Netplan and leaves the
existing WAN configuration untouched. Use --yes to skip interactive confirmation
(still requires root).
USAGE
}

while (($#)); do
  case "$1" in
    --yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die 'Run as root (sudo).'
[[ -r /etc/os-release ]] || die 'Cannot identify operating system.'
# shellcheck source=/etc/os-release
# . /etc/os-release
# [[ ${ID:-} == ubuntu && ${VERSION_ID:-} == 24.04 ]] || die 'This script supports Ubuntu 24.04 only.'

valid_token() { [[ $1 =~ ^[[:alnum:]_.:-]+$ ]]; }
valid_token "$WAN_IF" || die "Invalid WAN_IF: $WAN_IF"
valid_token "$LAN_IF" || die "Invalid LAN_IF: $LAN_IF"
[[ $WAN_IF != "$LAN_IF" ]] || die 'WAN_IF and LAN_IF must be different.'
[[ $LAN_SUBNET =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || die "Invalid LAN_SUBNET: $LAN_SUBNET"
[[ $LAN_ADDRESS =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || die "Invalid LAN_ADDRESS: $LAN_ADDRESS"
python3 - "$LAN_ADDRESS" "$LAN_SUBNET" <<'PY' || die 'LAN_ADDRESS must be a usable address inside LAN_SUBNET, with the same prefix length.'
import ipaddress
import sys
try:
    address = ipaddress.ip_interface(sys.argv[1])
    subnet = ipaddress.ip_network(sys.argv[2], strict=False)
    valid = address.version == 4 and subnet.version == 4 and address.network == subnet
    valid = valid and address.ip != subnet.network_address
    valid = valid and (subnet.num_addresses <= 2 or address.ip != subnet.broadcast_address)
except ValueError:
    valid = False
sys.exit(0 if valid else 1)
PY
[[ $SSH_PORT =~ ^[0-9]+$ ]] && ((SSH_PORT >= 1 && SSH_PORT <= 65535)) || die "Invalid SSH_PORT: $SSH_PORT"

for path in \
  hardening/sshd_config \
  dns/named.conf.options dns/named.conf.local dns/db.innovate.lab \
  dhcp/kea-dhcp4.conf fw/before.rules; do
  [[ -s "$REPO_ROOT/$path" ]] || die "Required configuration is missing or empty: $REPO_ROOT/$path"
done

if [[ ! -d "/sys/class/net/$WAN_IF" || ! -d "/sys/class/net/$LAN_IF" ]]; then
  die "Expected network interfaces '$WAN_IF' and '$LAN_IF' must exist before deployment."
fi

cat <<WARNING
This will install packages, replace service configuration, restart SSH on port $SSH_PORT,
and enable UFW. Ensure you have console/out-of-band access. The repository's sample
Kea and NAT interface/subnet values will be normalized to $LAN_IF, $WAN_IF, and $LAN_SUBNET.
Netplan will persist $LAN_ADDRESS on $LAN_IF; the existing WAN configuration is not changed.
WARNING
if ((ASSUME_YES == 0)); then
  [[ -t 0 ]] || die 'Non-interactive invocation requires --yes.'
  read -r -p 'Continue? [y/N] ' answer
  [[ $answer == [yY] || $answer == [yY][eE][sS] ]] || die 'Cancelled.'
fi

# Preserve pre-existing configurations before apt can create or update defaults.
backup_dir="$BACKUP_ROOT/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p -m 0700 "$backup_dir"
readonly backup_dir
readonly manifest="$backup_dir/manifest.tsv"
: > "$manifest"
chmod 0600 "$manifest"

backup_file() {
  local target="$1" rel
  rel="${target#/}"
  if [[ -e $target || -L $target ]]; then
    mkdir -p "$backup_dir/$(dirname -- "$rel")"
    cp -a -- "$target" "$backup_dir/$rel"
    printf 'present\t%s\n' "$rel" >> "$manifest"
  else
    printf 'absent\t%s\n' "$rel" >> "$manifest"
  fi
}

for target in \
  /etc/ssh/sshd_config \
  /etc/bind/named.conf.options /etc/bind/named.conf.local /etc/bind/db.innovate.lab \
  /etc/kea/kea-dhcp4.conf \
  /etc/ufw/before.rules /etc/default/ufw \
  /etc/sysctl.d/99-appliance-forwarding.conf \
  "$NETPLAN_FILE"; do
  backup_file "$target"
done
log "Backed up existing files (and recorded absent paths) in $backup_dir"

log 'Installing required packages.'
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  openssh-server bind9 bind9-utils dnsutils kea-dhcp4-server ufw iptables netplan.io

# Kea's Ubuntu service runs as _kea (or kea on some package builds); grant only
# its service group read access to the DHCP configuration.
kea_group=''
if getent group _kea >/dev/null; then
  kea_group='_kea'
elif getent group kea >/dev/null; then
  kea_group='kea'
else
  die 'Kea service group (_kea or kea) was not created by the package.'
fi

log 'Deploying configurations with restrictive ownership and modes.'
install -d -o root -g bind -m 0750 /etc/bind
install -d -o bind -g bind -m 0750 /etc/bind/zones
install -d -o root -g "$kea_group" -m 0750 /etc/kea
install -d -o root -g root -m 0755 /etc/ssh /etc/ufw /etc/sysctl.d /etc/netplan

# Stage transformed versions first; repository defaults disagree on the sample
# interface names and the NAT source uses the host address with a /24 mask.
tmpdir="$(mktemp -d)"
cleanup() { rm -rf -- "$tmpdir"; }
trap cleanup EXIT

install -m 0600 "$REPO_ROOT/hardening/sshd_config" "$tmpdir/sshd_config"
install -m 0640 "$REPO_ROOT/dns/named.conf.options" "$tmpdir/named.conf.options"
install -m 0640 "$REPO_ROOT/dns/named.conf.local" "$tmpdir/named.conf.local"
install -m 0640 "$REPO_ROOT/dns/db.innovate.lab" "$tmpdir/db.innovate.lab"
install -m 0640 "$REPO_ROOT/dhcp/kea-dhcp4.conf" "$tmpdir/kea-dhcp4.conf"
install -m 0640 "$REPO_ROOT/fw/before.rules" "$tmpdir/before.rules"

# Keep the delivered sample's service settings, adapting only its documented
# ens37/ens33 and subnet mismatches to the actual deployment topology.
sed -i -E "s/\"interfaces\"[[:space:]]*:[[:space:]]*\[[^]]*\]/\"interfaces\": [ \"$LAN_IF\" ]/" "$tmpdir/kea-dhcp4.conf"
sed -i -E "s#-s[[:space:]]+10\.115\.0\.250/24[[:space:]]+-o[[:space:]]+ens33#-s $LAN_SUBNET -o $WAN_IF#" "$tmpdir/before.rules"

# Add only the LAN address in a separate Netplan file; do not redefine the WAN.
cat > "$tmpdir/99-network-appliance-lan.yaml" <<NETPLAN
network:
  version: 2
  ethernets:
    "$LAN_IF":
      dhcp4: false
      addresses:
        - $LAN_ADDRESS
NETPLAN

install -o root -g root -m 0600 "$tmpdir/sshd_config" /etc/ssh/sshd_config
install -o root -g bind -m 0640 "$tmpdir/named.conf.options" /etc/bind/named.conf.options
install -o root -g bind -m 0640 "$tmpdir/named.conf.local" /etc/bind/named.conf.local
install -o bind -g bind -m 0640 "$tmpdir/db.innovate.lab" /etc/bind/db.innovate.lab
install -o root -g "$kea_group" -m 0640 "$tmpdir/kea-dhcp4.conf" /etc/kea/kea-dhcp4.conf
install -o root -g root -m 0640 "$tmpdir/before.rules" /etc/ufw/before.rules
install -o root -g root -m 0600 "$tmpdir/99-network-appliance-lan.yaml" "$NETPLAN_FILE"

# Persist IPv4 forwarding without editing the administrator-managed sysctl.conf.
cat > /etc/sysctl.d/99-appliance-forwarding.conf <<'SYSCTL'
net.ipv4.ip_forward=1
SYSCTL
chown root:root /etc/sysctl.d/99-appliance-forwarding.conf
chmod 0644 /etc/sysctl.d/99-appliance-forwarding.conf

log 'Validating service and Netplan configurations before enabling/restarting services.'
netplan generate
/usr/sbin/sshd -t -f /etc/ssh/sshd_config
named-checkconf -z
named-checkzone innovate.lab /etc/bind/db.innovate.lab
kea-dhcp4 -t /etc/kea/kea-dhcp4.conf
iptables-restore --test < /etc/ufw/before.rules

log "Applying Netplan LAN address $LAN_ADDRESS on $LAN_IF; WAN settings are unchanged."
netplan apply

log 'Enabling IPv4 forwarding.'
sysctl --system >/dev/null

# Open firewall paths before starting/restarting daemons. Preserve existing UFW
# rules; adding these rules is idempotent and does not reset the ruleset.
log 'Applying UFW policy and appliance allowlist.'
ufw default deny incoming
ufw default allow outgoing
ufw default allow routed
ufw allow in on "$WAN_IF" to any port "$SSH_PORT" proto tcp comment 'SSH Admin'
ufw allow in on "$LAN_IF" to any port 53 comment 'BIND9 DNS'
ufw allow in on "$LAN_IF" to any port 67 proto udp comment 'Kea DHCPv4'

# Ubuntu uses socket activation on some installations. Stop/disable it so sshd
# listens on the configured port, then manage the ssh service directly.
if systemctl list-unit-files ssh.socket --no-legend 2>/dev/null | grep -q '^ssh\.socket'; then
  systemctl disable --now ssh.socket || true
fi

log 'Starting services in dependency order: BIND9, Kea DHCPv4, SSH, then UFW.'
systemctl enable --now named
systemctl restart named
systemctl enable --now kea-dhcp4-server
systemctl restart kea-dhcp4-server
systemctl enable ssh
systemctl restart ssh
ufw --force enable

log 'Deployment complete.'
log "LAN is configured as $LAN_ADDRESS on $LAN_IF; WAN configuration was left unchanged."
log "SSH is configured for TCP/$SSH_PORT on $WAN_IF; confirm access from a second session."
log "Backup: $backup_dir"
log 'Run scripts/verify_appliance.sh.sample after reviewing its checks and adapting if needed.'
