# Suricata IDS Lab Command Cheat Sheet

## Network
ip -br addr
ip route
ping -c 3 <CLIENT_IP>
ss -tulnp
sudo tcpdump -ni <INTERFACE> tcp port 4444

## Install
sudo apt update
sudo apt install -y suricata jq netcat-openbsd

## Verify
suricata -V
sudo suricata -T -c /etc/suricata/suricata.yaml
pgrep -a suricata

## Rule
sudo nano /etc/suricata/rules/local.rules
alert tcp any any -> $HOME_NET 4444 (msg:"LAB Netcat TCP 4444 Test"; flags:S; sid:1000001; rev:1;)

## Start
sudo suricata -c /etc/suricata/suricata.yaml -i <INTERFACE>

## Logs
sudo tail -f /var/log/suricata/fast.log
sudo tail -f /var/log/suricata/eve.json

## Search
sudo grep -n "LAB Netcat TCP 4444 Test" /var/log/suricata/fast.log
sudo grep -n "1000001" /var/log/suricata/fast.log

## JSON
sudo jq 'select(.event_type=="alert" and .alert.signature_id==1000001)' /var/log/suricata/eve.json
sudo jq -r 'select(.event_type=="alert" and .alert.signature_id==1000001) | [.timestamp,.src_ip,.src_port,.dest_ip,.dest_port,.proto,.alert.signature] | @tsv' /var/log/suricata/eve.json

## Netcat
nc -lvnp 4444
nc -vz <SURICATA_IP> 4444
