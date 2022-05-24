#!/bin/sh

# many thanks to Jimmy-Z with his script: https://gist.github.com/Jimmy-Z/6120988090b9696c420385e7e42c64c4

# multi SSID with VLAN script, for ASUS AC56U with merlin
#
# setup before hand:
#       set "router" to "AP Mode"
#               this will put all ports and wireless in br0
#       create 2 guest network
#       enable Administration => System => Enable JFFS custom scripts and configs
#       put this script in /jffs/scripts/, name should be "services-start"
#               remember `chmod a+x services-start`
#       I strongly suggest you use static IP instead of DHCP
#               In my test, the "router" will pickup DHCP lease from VLAN 1 instead of VLAN 227
#       reboot
# some basic info of the original AP mode:
#       eth0 => WAN port
#       eth1~4 => LAN port 4~1, they're reversed
#       eth5 => WiFi 2.4G
#       eth6 => WiFi 5G
#       wl0.1, wl0.2 => WiFi 2.4G guest networks
# this setup:
#       WAN port (eth0) will be repurposed as a tagged port
#       LAN ports (eth1~4) and primary WiFi (eth5,6) will be on VLAN 227
#       guest network 1 will be on VLAN 11
#       guest network 2 will be on VLAN 12

echo "============== START 1 $(date) ==================" >> /jffs/scripts/log
ip a >> /jffs/scripts/log
ip r >> /jffs/scripts/log
brctl show >> /jffs/scripts/log
echo "============== END 1 $(date) ==================" >> /jffs/scripts/log

echo $PATH > /tmp/script_debug

# remove eth0 which will be reconfigured as a tagged port
brctl delif br0 eth0
# remove interfaces we're gonna move to other bridges
brctl delif br0 wl0.1
brctl delif br0 wl0.2

# add vlans
# interestingly, depending on the time passed since system boot,
# vlan interfaces will be named eth0.1 or vlan1, I guess some udev rules got loaded.
# so we use ip link instead of vconfig to specify a name explicitly.
ip link add link eth0 name eth0.10 type vlan id 10
ip link add link eth0 name eth0.30 type vlan id 30
ip link add link eth0 name eth0.40 type vlan id 40

ip link set eth0.10 up
ip link set eth0.30 up
ip link set eth0.40 up

# reconfigure br0, private LAN
brctl addif br0 eth0.10

# set up br1, guest LAN
brctl addbr br1
brctl addif br1 eth0.40
brctl addif br1 wl0.1
ip link set br1 up

# set up br2, another guest LAN for IoT devices
brctl addbr br2
brctl addif br2 eth0.30
brctl addif br2 wl0.2
ip link set br2 up

# seems like eapd reads config from these
# no need to set lan_ifname since it's already there
nvram set lan_ifnames="eth1 eth2 eth3 eth4 eth5 eth6 eth0.227"

nvram set lan1_ifnames="wl0.1 eth0.40"
nvram set lan1_ifname="br1"

nvram set lan2_ifnames="wl0.2 eth0.30"
nvram set lan2_ifname="br2"

# doesn't seem to affect anything, just make it align
nvram set br0_ifnames="eth1 eth2 eth3 eth4 eth5 eth6 eth0.10"

nvram set br1_ifnames="wl0.1 eth0.40"
nvram set br1_ifname="br1"

nvram set br2_ifnames="wl0.2 eth0.30"
nvram set br2_ifname="br2"

# we do NOT issue `nvram commit` here since it won't survive reboot anyway

# is there a better way to do this like `service restart eapd` ?
killall eapd
eapd

echo "============== START 2 $(date) ==================" >> /jffs/scripts/log
ip a >> /jffs/scripts/log
ip r >> /jffs/scripts/log
brctl show >> /jffs/scripts/log
echo "============== END 2 $(date) ==================" >> /jffs/scripts/log
