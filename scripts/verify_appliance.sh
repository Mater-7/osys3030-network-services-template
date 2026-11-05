#!/usr/bin/env bash
# Read-only health checks for the deployed network appliance.
# Defaults match scripts/deploy_appliance.sh; override them via environment as needed.
set -uo pipefail

WAN_IF="${WAN_IF:-ens18}"
LAN_IF="${LAN_IF:-ens19}"
LAN_SUBNET="${LAN_SUBNET:-10.115.0.0/24}"
# deploy_appliance.sh configures SSH on 2222 by default; set SSH_PORT=22 if changed.
SSH_PORT="${SSH_PORT:-2222}"
DNS_NAME="${DNS_NAME:-ns1.innovate.lab}"

PASS_COLOR=''
FAIL_COLOR=''
RESET_COLOR=''
if [[ -t 1 ]]; then
  PASS_COLOR=$'\033[0;32m'
  FAIL_COLOR=$'\033[0;31m'
  RESET_COLOR=$'\033[0m'
fi

FAIL_COUNT=0

pass() {
  printf '  %-58s [ %sPASS%s ]\n' "$1" "$PASS_COLOR" "$RESET_COLOR"
}

fail() {
  printf '  %-58s [ %sFAIL%s ]\n' "$1" "$FAIL_COLOR" "$RESET_COLOR"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check() {
  local description="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    pass "$description"
  else
    fail "$description"
  fi
}

check_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }
check_service() { systemctl is-active --quiet "$1"; }
check_named_config() { command -v named-checkconf >/dev/null 2>&1 && named-checkconf -z /etc/bind/named.conf; }
check_kea_config() { command -v kea-dhcp4 >/dev/null 2>&1 && kea-dhcp4 -t /etc/kea/kea-dhcp4.conf; }
check_ssh_config() { command -v sshd >/dev/null 2>&1 && sshd -t -f /etc/ssh/sshd_config; }

listening() {
  local protocol="$1" port="$2"
  command -v ss >/dev/null 2>&1 || return 1
  if [[ $protocol == udp ]]; then
    ss -H -lun | awk -v p="$port" '$4 ~ (":" p "$") { found=1 } END { exit !found }'
  else
    ss -H -ltn | awk -v p="$port" '$4 ~ (":" p "$") { found=1 } END { exit !found }'
  fi
}

ufw_active() {
  command -v ufw >/dev/null 2>&1 && ufw status | grep -q '^Status: active$'
}

ufw_rule_present() {
  local port="$1" protocol="$2" iface="$3" status
  status="$(ufw status)" || return 1
  grep -Eq "^${port}(/${protocol})? on ${iface}[[:space:]]+ALLOW IN([[:space:]]|$)" <<< "$status"
}

nat_masquerade_present() {
  command -v iptables >/dev/null 2>&1 || return 1
  iptables -t nat -C POSTROUTING -s "$LAN_SUBNET" -o "$WAN_IF" -j MASQUERADE
}

dns_resolves_locally() {
  command -v dig >/dev/null 2>&1 || return 1
  local answer
  answer="$(dig +time=2 +tries=1 @127.0.0.1 "$DNS_NAME" A +short)" || return 1
  [[ $answer =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]
}

ipv4_forwarding_enabled() {
  [[ $(sysctl -n net.ipv4.ip_forward 2>/dev/null) == 1 ]]
}

valid_settings() {
  [[ $WAN_IF =~ ^[[:alnum:]_.:-]+$ && $LAN_IF =~ ^[[:alnum:]_.:-]+$ ]] || return 1
  [[ $WAN_IF != "$LAN_IF" ]] || return 1
  [[ $LAN_SUBNET =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]] || return 1
  [[ $SSH_PORT =~ ^[0-9]+$ ]] && ((SSH_PORT >= 1 && SSH_PORT <= 65535)) || return 1
  [[ $DNS_NAME =~ ^[[:alnum:]_.-]+$ ]]
}

printf '%s\n' '============================================================' \
  '  Network Appliance Health & Verification' \
  '============================================================'

check 'Verification settings are valid' valid_settings
if ! valid_settings; then
  printf '  Check WAN_IF, LAN_IF, LAN_SUBNET, SSH_PORT, and DNS_NAME.\n'
  exit 2
fi
check 'Run as root (required for firewall/NAT checks)' check_root

printf '\n%s\n' '--- BIND9 DNS ---'
check 'BIND9 service is active' check_service named
check 'BIND configuration syntax and zones (named-checkconf)' check_named_config
check 'DNS listening on UDP port 53' listening udp 53
check "Local DNS resolves ${DNS_NAME}" dns_resolves_locally

printf '\n%s\n' '--- Kea DHCPv4 ---'
check 'Kea DHCPv4 service is active' check_service kea-dhcp4-server
check 'Kea configuration syntax (kea-dhcp4 -t)' check_kea_config
check 'DHCP listening on UDP port 67' listening udp 67

printf '\n%s\n' '--- OpenSSH ---'
check 'OpenSSH service is active' check_service ssh
check 'OpenSSH configuration syntax (sshd -t)' check_ssh_config
check "SSH listening on TCP port ${SSH_PORT}" listening tcp "$SSH_PORT"

printf '\n%s\n' '--- Firewall & Routing ---'
check 'UFW firewall is active' ufw_active
check "UFW allows SSH TCP/${SSH_PORT} on ${WAN_IF}" ufw_rule_present "$SSH_PORT" tcp "$WAN_IF"
check "UFW allows DNS port 53 on ${LAN_IF}" ufw_rule_present 53 '' "$LAN_IF"
check "UFW allows DHCP UDP/67 on ${LAN_IF}" ufw_rule_present 67 udp "$LAN_IF"
check 'IPv4 packet forwarding is enabled' ipv4_forwarding_enabled
check "iptables NAT MASQUERADE for ${LAN_SUBNET} via ${WAN_IF}" nat_masquerade_present

printf '%s\n' '============================================================'
if ((FAIL_COUNT == 0)); then
  printf '  %sAll appliance health checks passed.%s\n' "$PASS_COLOR" "$RESET_COLOR"
  exit 0
fi
printf '  %s%d check(s) failed; review the appliance configuration.%s\n' "$FAIL_COLOR" "$FAIL_COUNT" "$RESET_COLOR"
exit 1
