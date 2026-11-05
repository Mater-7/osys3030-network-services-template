# AI Automation & Code Audit Log

> **Student Name:** Carter 
> **Student ID:** w0521289  
> **AI Tool Used:** Github Co-pilot  

---

## 1. Executive Summary

I honestly did not want to use AI to verify with a script since AI often messes up verification/deployment scripts, however I copied the exact prompt in the Notion, and it generated a decent looking script. For safety reasons I created a VM with the same Ubuntu server .iso, and I tested the script on the newly created virtual machine. It seemly worked however I noticed the script did not apply the correct IP address.

---

## 2. Prompt Log

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
