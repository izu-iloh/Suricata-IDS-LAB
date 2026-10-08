# Suricata IDS Practical Lab

Beginner-friendly, copy-paste-ready Suricata Intrusion Detection System (IDS) lab for an **authorized cybersecurity lab**.

## Lab Goal
Install and configure Suricata, identify the monitored interface, add a custom detection rule, generate controlled TCP traffic with Netcat, trigger an alert, and analyze `fast.log` and `eve.json`.

## Learning Objectives
- Identify the correct network interface and IP addresses.
- Install and verify Suricata.
- Configure `HOME_NET` and the monitored interface.
- Create and load a local Suricata rule.
- Generate benign test traffic with Netcat.
- Start Suricata and verify packet capture.
- Trigger and interpret IDS alerts.
- Search `fast.log` with `grep` and inspect JSON alerts with `jq`.
- Troubleshoot common lab connectivity and alerting problems.

## Authorized Lab Topology

```text
[CLIENT]
CLIENT_IP=<CLIENT_IP>
        |
        | TCP test traffic
        |
[ROUTER / VIRTUAL SWITCH]
        |
        |
[SURICATA SENSOR]
SURICATA_IP=<SURICATA_IP>
INTERFACE=<INTERFACE>
```

Use only systems, networks, and traffic you are authorized to test.

## Placeholders
Replace these before running commands:
- `<SURICATA_IP>` — IP address of the Suricata sensor.
- `<CLIENT_IP>` — IP address of the test client.
- `<INTERFACE>` — interface carrying the test traffic, e.g. `eth0`, `ens33`, or `enp0s3`.
- `<SURICATA_CONFIG>` — normally `/etc/suricata/suricata.yaml`.
- `<LOCAL_RULES>` — normally `/etc/suricata/rules/local.rules`.

## Prerequisites
- Kali/Debian/Ubuntu Linux VM for the sensor.
- A second Linux VM or authorized host as the client.
- Both systems connected to the same lab network or otherwise routable.
- Sudo privileges on the sensor.
- `curl`/package manager access if installing packages.
- Basic Linux terminal knowledge.
- `netcat` (`nc`) on the client.
- `jq` on the sensor for JSON analysis.

## 1. Identify the Network Interface

On the Suricata sensor:

```bash
ip -br addr
ip route
```

Expected output resembles:

```text
eth0             UP             <SURICATA_IP>/24
```

and:

```text
default via <GATEWAY_IP> dev eth0
<SUBNET>/24 dev eth0 proto kernel scope link src <SURICATA_IP>
```

The interface shown beside the connected route is a strong candidate for `<INTERFACE>`. Confirm it carries the lab traffic before starting Suricata.

Test reachability:

```bash
ping -c 3 <CLIENT_IP>
```

Expected: replies from `<CLIENT_IP>`. If you get `Destination Host Unreachable` or `No route to host`, see Troubleshooting.

## 2. Install Suricata

On Debian/Kali/Ubuntu:

```bash
sudo apt update
sudo apt install -y suricata jq netcat-openbsd
```

Verify:

```bash
suricata --build-info
suricata -V
jq --version
nc -h
```

Expected: Suricata version/build information, a `jq` version, and Netcat help/version output.

Check the configuration:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

Expected ending:

```text
Notice: Configuration provided was successfully loaded.
Notice: Suricata main thread initialized.
```

Exact wording varies by version; the important result is that configuration validation succeeds without fatal errors.

## 3. Configure HOME_NET and the Interface

Back up the configuration:

```bash
sudo cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak
```

Open it:

```bash
sudo nano /etc/suricata/suricata.yaml
```

Find `HOME_NET` and set it to your lab subnet. Example:

```yaml
HOME_NET: "[192.168.56.0/24]"
```

Do **not** blindly copy that subnet; use the subnet shown by `ip route`.

For a basic interface-based capture, locate the `af-packet:` section. On versions where it is enabled, configure the correct interface, for example:

```yaml
af-packet:
  - interface: <INTERFACE>
```

If your installed configuration uses a different capture method (such as `pcap`), follow that configuration's syntax and keep the lab interface consistent.

Validate again:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

## 4. Create the Custom Detection Rule

Create/edit the local rule file:

```bash
sudo nano /etc/suricata/rules/local.rules
```

Add:

```text
alert tcp any any -> $HOME_NET 4444 (msg:"LAB Netcat TCP 4444 Test"; flags:S; sid:1000001; rev:1;)
```

### Rule explanation
- `alert` — generate an alert.
- `tcp` — inspect TCP traffic.
- `any any` — any source IP and source port.
- `-> $HOME_NET 4444` — traffic headed to port 4444 in the protected network.
- `msg` — human-readable alert message.
- `flags:S` — match TCP SYN packets, useful for detecting the initial connection attempt.
- `sid:1000001` — unique local signature ID for this lab.
- `rev:1` — rule revision.

Validate:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

Expected: no fatal rule/configuration errors and a successful configuration load.

## 5. Confirm the Local Rule Is Loaded

Depending on the package/version, use:

```bash
grep -n "local.rules" /etc/suricata/suricata.yaml
```

and:

```bash
sudo grep -n "LAB Netcat TCP 4444 Test" /etc/suricata/rules/local.rules
```

If your configuration uses `rule-files`, confirm `local.rules` appears there.

## 6. Generate Controlled Netcat Traffic

### On the client
Start a listener:

```bash
nc -lvnp 4444
```

Expected output is similar to:

```text
Listening on 0.0.0.0 4444
```

### From the client itself or a second authorized test host
If the client is separate from the sensor, use:

```bash
nc -vz <SURICATA_IP> 4444
```

For the cleanest topology, point the test connection at the Suricata-protected destination whose IP belongs to `$HOME_NET`.

For a two-host sensor/client lab where Suricata monitors the sensor's interface and the sensor is the destination, use:

```bash
nc -vz <SURICATA_IP> 4444
```

If the sensor is only monitoring traffic between two other hosts, replace `<SURICATA_IP>` with the authorized destination IP and ensure the sensor can actually observe that path.

### Generate a SYN without requiring a successful application session
The `nc -vz` test normally creates a TCP connection attempt. Even if the application connection is refused, the SYN can still be visible to Suricata.

## 7. Start Suricata

First stop any existing lab instance if appropriate:

```bash
sudo pkill suricata 2>/dev/null || true
```

Then start Suricata in the foreground for easy troubleshooting:

```bash
sudo suricata -c /etc/suricata/suricata.yaml -i <INTERFACE>
```

Leave this terminal running.

In a second terminal, watch alerts:

```bash
sudo tail -f /var/log/suricata/fast.log
```

And in a third terminal:

```bash
sudo tail -f /var/log/suricata/eve.json
```

If your distro stores logs elsewhere, check:

```bash
sudo grep -n "default-log-dir" /etc/suricata/suricata.yaml
```

## 8. Trigger and Analyze the Alert

From the authorized client:

```bash
nc -vz <SURICATA_IP> 4444
```

Then inspect:

```bash
sudo grep "LAB Netcat TCP 4444 Test" /var/log/suricata/fast.log
```

Expected pattern:

```text
[**] [1:1000001:1] LAB Netcat TCP 4444 Test [**]
```

You may also see source/destination IPs and ports.

For a compact search:

```bash
sudo grep -n "1000001" /var/log/suricata/fast.log
```

## 9. Analyze eve.json with jq

Search for the signature:

```bash
sudo jq 'select(.event_type=="alert" and .alert.signature_id==1000001)' /var/log/suricata/eve.json
```

Extract useful fields:

```bash
sudo jq -r '
select(.event_type=="alert" and .alert.signature_id==1000001) |
[.timestamp,.src_ip,.src_port,.dest_ip,.dest_port,.proto,.alert.signature] |
@tsv
' /var/log/suricata/eve.json
```

Expected columns resemble:

```text
timestamp    source_ip    source_port    destination_ip    4444    TCP    LAB Netcat TCP 4444 Test
```

Count matching alerts:

```bash
sudo jq '
select(.event_type=="alert" and .alert.signature_id==1000001)
' /var/log/suricata/eve.json | wc -l
```

Show all alert event types:

```bash
sudo jq 'select(.event_type=="alert")' /var/log/suricata/eve.json
```

## 10. Useful Verification Commands

Check that Suricata is running:

```bash
pgrep -a suricata
```

Check listening/active network sockets:

```bash
ss -tulnp
```

Check the interface sees packets:

```bash
sudo tcpdump -ni <INTERFACE> tcp port 4444
```

If packets appear in tcpdump but not in Suricata alerts, focus on the rule, `HOME_NET`, rule loading, and Suricata capture configuration.

Check logs:

```bash
sudo ls -lah /var/log/suricata/
```

## Expected Results

| Test | Expected result |
|---|---|
| `ip -br addr` | Correct lab interface and IP identified |
| `ip route` | Route to the test network exists |
| `suricata -T` | Configuration validates successfully |
| Local rule | SID `1000001` is present |
| `nc -vz ... 4444` | TCP connection attempt is generated |
| `tcpdump` | TCP SYN/traffic visible on monitored interface |
| `fast.log` | `LAB Netcat TCP 4444 Test` alert appears |
| `eve.json` | JSON alert with timestamp/IP/port/signature fields |
| `jq` query | Alert can be filtered and summarized |

## Troubleshooting

### `No route to host` / `Destination Host Unreachable`
Check:

```bash
ip addr
ip route
ping -c 3 <CLIENT_IP>
```

Verify both hosts are attached to the same intended virtual network, the destination IP is correct, and the interface is up:

```bash
ip link
```

Do not disable firewalls blindly. First identify whether a host firewall or network ACL is intentionally blocking the traffic.

### `Connection refused`
This usually means the destination is reachable but no process is listening on port 4444, or a firewall is actively rejecting it.

Start Netcat:

```bash
nc -lvnp 4444
```

Then test:

```bash
nc -vz <DESTINATION_IP> 4444
```

A refused connection can still generate a SYN alert because the custom rule matches the initial SYN.

### Wrong interface
Compare:

```bash
ip -br addr
ip route
sudo tcpdump -ni <INTERFACE> tcp port 4444
```

If tcpdump sees nothing, `<INTERFACE>` may be wrong or the traffic is not traversing that interface.

### Missing alerts
Check the rule:

```bash
sudo grep -n "LAB Netcat TCP 4444 Test" /etc/suricata/rules/local.rules
```

Check rule loading:

```bash
sudo suricata -T -c /etc/suricata/suricata.yaml
```

Check capture:

```bash
sudo tcpdump -ni <INTERFACE> tcp port 4444
```

Check Suricata:

```bash
pgrep -a suricata
```

Check logs:

```bash
sudo ls -lah /var/log/suricata/
```

Check `HOME_NET`. The destination must match the network represented by `$HOME_NET` for the rule as written.

### `jq: command not found`

```bash
sudo apt update
sudo apt install -y jq
```

### Permission denied when reading logs

Use `sudo`:

```bash
sudo grep "LAB Netcat TCP 4444 Test" /var/log/suricata/fast.log
sudo jq '.' /var/log/suricata/eve.json
```

## Verification Checklist

- [ ] Sensor and client are connected to the authorized lab network.
- [ ] `<SURICATA_IP>`, `<CLIENT_IP>`, and `<INTERFACE>` were replaced.
- [ ] Correct interface identified with `ip -br addr` / `ip route`.
- [ ] Suricata installed and version verified.
- [ ] `suricata -T` passes.
- [ ] `HOME_NET` represents the lab network.
- [ ] `local.rules` contains SID `1000001`.
- [ ] Netcat listener/test was executed.
- [ ] `tcpdump` confirmed test packets.
- [ ] `fast.log` contains the custom alert.
- [ ] `eve.json` contains the custom alert.
- [ ] `grep` successfully found the alert.
- [ ] `jq` successfully extracted alert fields.
- [ ] Evidence was captured without including secrets or unrelated personal data.

## Student Questions

1. What interface was monitored and why?
2. What is the purpose of `HOME_NET`?
3. What does `flags:S` match?
4. What does SID `1000001` identify?
5. What source and destination IP/port appeared in the alert?
6. Why can an alert appear even when Netcat reports `Connection refused`?
7. What is the difference between `fast.log` and `eve.json`?
8. Why is `jq` useful for analyzing `eve.json`?
9. What evidence proves that the packet reached the monitored interface?
10. How would you modify the rule to monitor another destination port?

## Practical Challenge

Create a second local rule that detects TCP SYN traffic to port `5555`.

Requirements:
- Use a new SID, e.g. `1000002`.
- Use a clear message.
- Start a Netcat test on port 5555.
- Trigger the alert.
- Prove the alert exists in both `fast.log` and `eve.json`.
- Use `jq` to extract timestamp, source IP, destination IP, destination port, and signature.
- Save sanitized evidence in `evidence/`.

Do not scan or generate traffic against systems outside your authorized lab.

## Evidence Suggestions
Save sanitized outputs such as:
- `ip -br addr`
- `ip route`
- successful `suricata -T`
- local rule
- Netcat test
- `tcpdump` proof
- `fast.log` alert
- selected `eve.json` fields

Do not commit passwords, tokens, private keys, or sensitive production logs.

## GitHub Workflow

```bash
git init
git add .
git commit -m "Add Suricata IDS practical lab"
git branch -M main
git remote add origin <YOUR_GITHUB_REPOSITORY_URL>
git push -u origin main
```

Replace `<YOUR_GITHUB_REPOSITORY_URL>` with your own repository URL.

## Disclaimer
This project is designed for authorized educational and defensive-security labs. Only monitor and generate traffic on systems and networks you own or have explicit permission to test.
