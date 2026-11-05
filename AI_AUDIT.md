# AI Automation & Code Audit Log

> **Student Name:** Carter 
> **Student ID:** w0521289  
> **AI Tool Used:** Github Co-pilot  

---

## 1. Executive Summary
'''
I honestly did not want to use AI to verify with a script since AI often messes up verification/deployment scripts, however I copied the exact prompt in the Notion, and it generated a decent looking script. For safety reasons I created a VM with the same Ubuntu server .iso, and I tested the script on the newly created virtual machine. It seemly worked however I noticed the script did not apply the correct IP address.
'''text
---

## 2. Prompt Log

### 2.1 Deployment Script Prompt
'''
Act as a Senior Linux DevOps Engineer. Using my attached Markdown guides and configuration files for SSH hardening, BIND9, Kea DHCPv4, and UFW with NAT masquerading on Ubuntu 24.04, generate a production-ready Bash script (scripts/deploy_appliance.sh). The script must install all packages, back up existing configs, deploy my custom config files into /etc/, set strict file permissions, and start/enable services in the correct dependency order.
```text

```

### 2.2 Verification Script Prompt
write a companion Bash verification script (scripts/verify_appliance.sh) with formatted [ PASS ] / [ FAIL ] indicators that tests every service on the appliance: verifies configuration syntax (named-checkconf, kea-dhcp4 -t), confirms systemd active states, checks listening ports (UDP 53, UDP 67, TCP 22), validates UFW rules and iptables NAT table entries, and tests local DNS resolution via dig
```text
```

---

## 3. Human-in-the-Loop Audit & Hallucination Corrections

The AI completely used hard-coded program calls for some reason despite installing all the required tools and adding them to path. so to call lets say "cat" it would write "/usr/bin/cat file.txt" in the script and it would often break since it really was too "safe"

The AI insisted on adding os version checking, I manually removed it since it was unnecessary for this assignment, and it was looking for a specific version of Ubuntu server that I did not have installed

| # | Service / Component | The AI's Hallucination / Error | The Fix Implemented |
| :--- | :--- | :--- | :--- |
| **1** | Used paths to execute programs | Instead of using the normal commands it used harded paths like "/usr/bin/echo "test" " it wouldn't run the commands at all.| | I removed the paths to the command and that fixed the problems |
| **2** | e.g., BIND9 | Forgot to set `chown -R bind:bind /etc/bind/zones` | Added explicit ownership fix before service start |
| **3** | e.g., UFW NAT | Added MASQUERADE rule at the bottom of `before.rules` instead of before `*filter` | Positioned the `*nat` table block before the `*filter` block per UFW requirements |

---

## 4. Testing & Verification Results

* **Date Tested:** [YYYY-MM-DD]
* **Target Environment:** [e.g., OSYS3030 Baseline Server (VMID 106)]
* **Verification Script Output:**
  ```text
  [Paste the terminal output of running sudo ./scripts/verify_appliance.sh showing PASS]
  ```

---

## 5. Attestation
I attest that I have personally reviewed, tested, and understand every line of code in the generated scripts. I am prepared to explain any part of these scripts or configuration files during an evaluation.
