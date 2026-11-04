# OSYS3030 - Linux Network Appliance Documentation

> **Student Name:** Carter W
> **Student ID / VMID:** w0521289
> **Repository:** [[Public GitHub URL]  ](https://github.com/Mater-7/osys3030-network-services-template)
> **Instructor:** Matt Redmond  
> **Course:** OSYS3030 - Network Services Using Linux  

---

## 1. Appliance Overview
A high-level summary of your multi-homed Linux server appliance, its purpose, and its role as a gateway/router for the private internal network.

* **Operating System:** Ubuntu Server 24.04 LTS (Noble Numbat)
* **Hostname:** 'ubuntuserver-cw'
* **Primary Roles:**
  * Router & Firewall (UFW + iptables NAT masquerading)
  * Recursive & Authoritative DNS (BIND9)
  * Dynamic Host Configuration Protocol (Kea DHCPv4)
  * Secure Remote Administration (OpenSSH)

---

## 2. Network Topology & Interfaces

```text
              +------------------------------------------------+
              |           WAN / outer Network / my network      |
              |            192.168.81.134                      |
              +---------------------+--------------------------+
                                    |
                                    | (DHCP / Static IP)
                                 [ens18]
                       +------------+------------+
                       |   OSYS3030 Linux Server |
                       |                         |
                       +------------+------------+
                                 [ens19]
                                    | (10.115.0.250/24)
                                    |
              +---------------------+--------------------+
              |        Isolated Private VLAN (vmbr5)      |
              |             10.115.0.0/24               |
              +---------------------+--------------------+
                                    |
                                    | (DHCP: 10.115.0.10 - .200)
                                 [eth0]
                       +------------+------------+
                       |    windows Client VM     |
                       |       (testerJester)       |
                       +-------------------------+
```

| Interface | Network Zone | IP Address / Subnet | Purpose |
| :--- | :--- | :--- | :--- |
| `ens18` | WAN / External | `192.168.81.134` | Upstream internet & SSH management |
| `ens19` | LAN / Internal | `10.115.0.250/24` | Default gateway & service binding for clients |

---

## 3. Implemented Services

| Directory | Service | Daemon | Listening Ports | Description |
| :--- | :--- | :--- | :--- | :--- |
| [`hardening/`](./hardening/) | SSH / Host Security | `sshd` | TCP 22 | Hardened SSH configuration, root restrictions |
| [`dns/`](./dns/) | BIND9 DNS | `named` | UDP/TCP 53 | Authoritative for `innovate.lab` & recursive forwarder |
| [`dhcp/`](./dhcp/) | Kea DHCPv4 | `kea-dhcp4` | UDP 67 | Scoped dynamic IP lease allocation for LAN |
| [`fw/`](./fw/) | UFW Firewall & NAT | `ufw` / `iptables` | N/A | State-tracking firewall & packet masquerading |
| [`scripts/`](./scripts/) | Automation | Bash | N/A | Automated deployment and verification scripts |

---

## 4. Base OS & Netplan Prerequisites
Update your system using sudo apt update && sudo apt upgrade -y 
Then ensure that your ip addressing is the same as mine, I used Vmware Workstation Pro, so my results will be different!


---

## 5. Automated Recovery & Verification

This appliance includes automated deployment and verification scripts located in [`scripts/`](./scripts/):

* **Deployment / Disaster Recovery:**
  ```bash
  sudo ./scripts/deploy_appliance.sh
  ```
* **Automated Health Check & Verification:**
  ```bash
  sudo ./scripts/verify_appliance.sh
  ```

See [`AI_AUDIT.md`](./AI_AUDIT.md) for documentation on how these scripts were generated using AI and audited for accuracy.

---

## 6. Peer Review Audit

* **Audited Classmate:** Eric W ()
* **Classmate Appliance Subnet:** `10.<PartnerID>.0.0/24`
* **Audit Summary:** [2–3 sentences summarizing your review of your peer's repository, configs, and recovery documentation].
