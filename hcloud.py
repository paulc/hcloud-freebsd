#!/usr/local/bin/python3

import email,json,pathlib,subprocess
import requests
import yaml

def sysrc(key,val=None):
    # Read/write rc.conf values using sysrc
    if val:
        subprocess.run(['/usr/sbin/sysrc','{}={}'.format(key,val)],check=True)
    else:
        subprocess.run(['/usr/sbin/sysrc',key],check=True)

def runrc(name,check=True):
    # Rerun service initialisation (picking up new rc.sonf values)
    subprocess.run(['/usr/sbin/service',name,'start'],check=check)
    
def savejson(name,data):
    # Save section as JSON
    with open(name,'w') as f:
        json.dump(data,f,indent=4)
        f.write("\n")

def vendor_data(data):
    # Handle vendor_data section - we can ignore this but save anyway
    # Extract multipart-mime files ('hc-boot-script','cloud-config')
    vendor_data = email.message_from_string(data)
    for p in vendor_data.walk():
        if not p.is_multipart():
            name = p.get_filename()
            with open(name,"w") as f:
                f.write(p.get_payload())
                f.write("\n")

def hostname(name):
    # Set hostname
    sysrc('hostname',name)
    runrc('hostname')

def sshkeys(keys):
    # Write SSH keys to /root/.ssh/authorized_keys
    sshdir = pathlib.Path('/root/.ssh')
    sshdir.mkdir(mode=0o700,exist_ok=True)
    ak = sshdir / 'authorized_keys'
    with ak.open('w') as f:
        for sshkey in keys:
            f.write(sshkey)
            f.write('\n')
    ak.chmod(0o600)

def network_config(config):
    # You might expect all network interfaces to be defined here
    # but only primary interface data is provided (does not include
    # private interfaces) - though we go through list anyway
    for iface in config:
        # Rename interface from ethXX to vtnetXX
        ifname = iface['name'].replace('eth','vtnet')
        for subnet in iface['subnets']:
            if subnet.get('ipv4',False):
                # We always configure primary interface IPv4 via DHCP
                if subnet['type'] == 'dhcp':
                    sysrc('ifconfig_{}'.format(ifname),'DHCP')
            elif subnet.get('ipv6',False):
                # Configure static IPv6 address 
                if subnet['type'] == 'static':
                    address,prefix = subnet['address'].split('/')
                    sysrc('ifconfig_{}_ipv6'.format(ifname),
                        'inet6 {} prefixlen {}'.format(address,prefix))
                if subnet.get('gateway',False):
                    sysrc('ipv6_defaultrouter',
                            subnet['gateway'].replace('eth','vtnet'))
    # We now configure any unconfigured interfaces
    ifaces = subprocess.run(['/sbin/ifconfig','-ld','ether'],
                                capture_output=True,check=True)
    for ifname in ifaces.stdout.decode('ascii').split():
        sysrc('ifconfig_{}'.format(ifname),'DHCP')
    # We now reconfigure network interfaces and routing
    runrc('netif')
    runrc('routing',False)  # Ignore errors from existing routes

def hcloud_metadata():
    # Get instance metadata
    r = requests.get('http://169.254.169.254/hetzner/v1/metadata')
    if r.status_code != 200:
        raise ValueError("Error fetching cloud-config")

    # Parse YAML
    config = yaml.safe_load(r.text)

    # Handle sections
    for k,v in config.items():
        if k == "vendor_data":
            vendor_data(v)
        else:
            # Save config section to local directory (usually /var/hcloud)
            savejson(k,v)
            if k == 'hostname':
                hostname(v)
            elif k == 'public-keys':
                sshkeys(v)
            elif k == 'network-config':
                network_config(v['config'])

def hcloud_userdata():
    # Get instance userdata
    r = requests.get('http://169.254.169.254/hetzner/v1/userdata')
    if r.status_code != 200:
        raise ValueError("Error fetching cloud-config")

    # Write to 'user-data'
    userdata = pathlib.Path('./user-data')
    with userdata.open('w') as f:
        f.write(r.text)
    userdata.chmod(0o700)
    subprocess.run(['./user-data'],check=True)

if __name__ == '__main__':
    # Get metadata
    hcloud_metadata()
    # Get userdate
    hcloud_userdata()
