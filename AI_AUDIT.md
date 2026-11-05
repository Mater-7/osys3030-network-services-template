# AI Automation & Code Audit Log

> **Student Name:** Carter 
> **Student ID:** w0521289  
> **AI Tool Used:** Github Co-pilot  

---

## 1. Executive Summary

I honestly did not want to use AI to verify with a script since AI often messes up verification/deployment scripts, however I copied the exact prompt in the Notion, and it generated a decent looking script. For safety reasons I created a VM with the same Ubuntu server .iso, and I tested the script on the newly created virtual machine. It seemly worked however I noticed the script did not apply the correct IP address.

---

## 2. Prompt Log
# Chat Log

This file records the user and assistant messages from the conversation about deploying and verifying the network appliance. Tool/API activity is not part of the chat transcript. The user supplied full inline file contents multiple times; to avoid duplicating large source files in this log, those payloads are identified by their path and source URL rather than reproduced here. The original source references are included so the exact file contents can be retrieved.

---

## 1

**User**

`<session_context login="Mater-7" date="2026-11-05" />`

**User**

File path: `scripts/deploy_appliance.sh`  
Source URL: https://github.com/Mater-7/osys3030-network-services-template/blob/main/scripts/deploy_appliance.sh  
Repo: `Mater-7/osys3030-network-services-template`  
CommitOID: `66fa55acf87c984cfd9424d8336d8b2cb4b5f276`

The user included the full contents of the deploy script inline.

**User**

Got this err. mater@potato:~/osys3030-network-services-template$ sudo WAN_IF=ens33 LAN_IF=ens37 LAN_SUBNET=10.115.0.0/24 ./scripts/deploy_appliance.sh
sudo: cannot execute '/home/mater/osys3030-network-services-template/scripts/deploy_appliance.sh': Permission denied (os error 13)
mater@potato:~/osys3030-network-services-template$ sudo !!
sudo sudo WAN_IF=ens33 LAN_IF=ens37 LAN_SUBNET=10.115.0.0/24 ./scripts/deploy_appliance.sh
sudo: cannot execute '/home/mater/osys3030-network-services-template/scripts/deploy_appliance.sh': Permission denied (os error 13)

**Assistant**

The script is probably missing its executable bit. Try running it through Bash:

```bash
sudo env WAN_IF=ens33 LAN_IF=ens37 LAN_SUBNET=10.115.0.0/24 bash ./scripts/deploy_appliance.sh
```

To make it executable for future runs:

```bash
chmod +x scripts/deploy_appliance.sh
```

Then rerun your original command. If you maintain the repository and want that permission recorded in Git, run `git update-index --chmod=+x scripts/deploy_appliance.sh` and commit the change.

If it still fails, check whether the filesystem is mounted with `noexec` (`findmnt -no OPTIONS /home`); running through Bash may still work in that case. Also, `sudo !!` repeated the previous command—including `sudo`—so it became `sudo sudo`; just enter the command once.

**Assistant**

**Caution:** this script changes SSH, firewall, and network-service settings. Confirm console/out-of-band access and the interface names before proceeding.

---

## 2

**User**

File path: `scripts/deploy_appliance.sh`  
Source URL: /Mater-7/osys3030-network-services-template/blob/main/scripts/deploy_appliance.sh  
Repo: `Mater-7/osys3030-network-services-template`  
CommitOID: `66fa55acf87c984cfd9424d8336d8b2cb4b5f276`

The user included the full contents of the deploy script inline (same source payload as above).

**User**

`./scripts/deploy_appliance.sh: line 163: /usr/sbin/named-checkconf: No such file or directory`

**Assistant**

The script hard-codes `named-checkconf` as `/usr/sbin/named-checkconf`, but that path doesn’t exist on your system. Check where the package installed it:

```bash
command -v named-checkconf
dpkg -L bind9-utils | grep '/named-checkconf$'
```

If the first command prints a path, edit `scripts/deploy_appliance.sh` and replace:

```bash
/usr/sbin/named-checkconf -z
```

with:

```bash
named-checkconf -z
```

Do the same for `named-checkzone` if its hard-coded `/usr/sbin/` path is also missing. If neither command finds the checker, install or reinstall the package:

```bash
sudo apt-get install --reinstall bind9-utils
```

Then rerun the script. It has already copied configuration files into `/etc`; keep the backup directory it printed earlier, since that contains the pre-deployment files.

---

## 3

**User**

The user asked for a companion Bash verification script at `scripts/verify_appliance.sh`, with formatted `[ PASS ]` / `[ FAIL ]` indicators to test configuration syntax, systemd active states, listening ports (UDP 53, UDP 67, TCP 22), UFW rules, iptables NAT entries, and local DNS resolution using `dig`. The request was sent twice, once with the typo “rite” and then corrected to “write”.

**Assistant**

I’m waiting for your response to the pending confirmation before I can add the verification script to the repository.

**User**

`@Copilot Accepted Confirmation: Are you sure?`

**Assistant**

I’ve added the verification script at:

`scripts/verify_appliance.sh`

It checks:
- BIND config validity via `named-checkconf`
- Kea config syntax via `kea-dhcp4 -t`
- systemd active states for `named`, `kea-dhcp4-server`, and `ssh`
- listening ports for UDP 53, UDP 67, and TCP 22
- UFW allow rules and NAT MASQUERADE behavior
- IPv4 forwarding
- local DNS resolution via `dig`

It reports results with `[ PASS ]` / `[ FAIL ]` formatting and exits nonzero if any checks fail.

You can run it with:

```bash
sudo ./scripts/verify_appliance.sh
```

If you want, I can also tune it for your exact deployment assumptions (for example, custom SSH port, interface names, or DNS name).

---

## 4

**User**

How can I change the adapters for this script?  on the cmd line.

**Assistant**

Set `WAN_IF` and `LAN_IF` on the command line before the script. For your adapters, run:

```bash
sudo env WAN_IF=ens33 LAN_IF=ens37 LAN_SUBNET=10.115.0.0/24 ./scripts/deploy_appliance.sh
```

Replace `ens33` and `ens37` with your actual interface names. You can check them with:

```bash
ip -br link
```

The script also accepts `SSH_PORT` this way, if you want to change its default:

```bash
sudo env WAN_IF=ens33 LAN_IF=ens37 LAN_SUBNET=10.115.0.0/24 SSH_PORT=2222 ./scripts/deploy_appliance.sh
```

Confirm console or out-of-band access before deploying, since this changes network and firewall settings.

---

## 5

**User**

`{"url":"https://github.com/Mater-7/osys3030-network-services-template/edit/main/AI_AUDIT.md"}`

**User**

The user included the full contents of the current `scripts/deploy_appliance.sh` inline, with source URL https://github.com/Mater-7/osys3030-network-services-template/blob/main/scripts/deploy_appliance.sh and commit `7f2d3effc42d2d81efe076318583d45d039d12e1`. This version calls `named-checkconf -z` without the `/usr/sbin/` prefix. The user then asked:

Create an entire log of our chat in the root of this project including my full prompts and yours as well

### 2.1 Deployment Script Prompt
```
Act as a Senior Linux DevOps Engineer. Using my attached Markdown guides and configuration files for SSH hardening, BIND9, Kea DHCPv4, and UFW with NAT masquerading on Ubuntu 24.04, generate a production-ready Bash script (scripts/deploy_appliance.sh). The script must install all packages, back up existing configs, deploy my custom config files into /etc/, set strict file permissions, and start/enable services in the correct dependency order.
```
### 2.2 Verification Script Prompt
```
write a companion Bash verification script (scripts/verify_appliance.sh) with formatted [ PASS ] / [ FAIL ] indicators that tests every service on the appliance:
verifies configuration syntax (named-checkconf, kea-dhcp4 -t), confirms systemd active states, checks listening ports (UDP 53, UDP 67, TCP 22), validates UFW rules and iptables NAT table entries, and tests local DNS resolution via dig
```

---

## 3. Human-in-the-Loop Audit & Hallucination Corrections

The AI completely used hard-coded program calls for some reason despite installing all the required tools and adding them to path. so to call lets say "cat" it would write "/usr/bin/cat file.txt" in the script and it would often break since it really was too "safe"

The AI insisted on adding os version checking, I manually removed it since it was unnecessary for this assignment, and it was looking for a specific version of Ubuntu server that I did not have installed

| # | Service / Component | The AI's Hallucination / Error | The Fix Implemented |
| :--- | :--- | :--- | :--- |
| **1** | Used paths to execute programs | Instead of using the normal commands it used harded paths like "/usr/bin/echo "test" " it wouldn't run the commands at all.|  I removed the paths to the command and that fixed the problems |
| **2** | OS version checks |  The deploy script checked what Ubuntu version that we were using, and it was completely unnecessary, and it broke the script | Commented it out, and removed it entirely  |
| **3** | UFW wasn't getting checked properly | The UFW firewall was setup correctly, but the verification script was not functioning at all | I updated the script using a prompt, and it did fix itself |

'''

## 4. Testing & Verification Results

* **Date Tested:** [2026-04-11]
* **Target Environment:** OSYS3030
* **Verification Script Output:**
```
  ============================================================
  Network Appliance Health & Verification
============================================================
  Verification settings are valid                            [ PASS ]
  Run as root (required for firewall/NAT checks)             [ PASS ]

--- BIND9 DNS ---
  BIND9 service is active                                    [ PASS ]
  BIND configuration syntax and zones (named-checkconf)      [ PASS ]
  DNS listening on UDP port 53                               [ PASS ]
  Local DNS resolves ns1.innovate.lab                        [ PASS ]

--- Kea DHCPv4 ---
  Kea DHCPv4 service is active                               [ PASS ]
  Kea configuration syntax (kea-dhcp4 -t)                    [ PASS ]
  DHCP listening on UDP port 67                              [ PASS ]

--- OpenSSH ---
  OpenSSH service is active                                  [ PASS ]
  OpenSSH configuration syntax (sshd -t)                     [ PASS ]
  SSH listening on TCP port 2222                             [ PASS ]

--- Firewall & Routing ---
  UFW firewall is active                                     [ PASS ]
  UFW allows SSH TCP/2222 on ens33                           [ PASS ]
  UFW allows DNS port 53 on ens37                            [ PASS ]
  UFW allows DHCP UDP/67 on ens37                            [ PASS ]
  IPv4 packet forwarding is enabled                          [ PASS ]
  iptables NAT MASQUERADE for 10.115.0.0/24 via ens33        [ PASS ]
============================================================
```

---

## 5. Attestation
I attest that I have personally reviewed, tested, and understand every line of code in the generated scripts. I am prepared to explain any part of these scripts or configuration files during an evaluation.
