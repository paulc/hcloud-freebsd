#!/usr/local/bin/python3

import email,json,pathlib,subprocess
import requests
import yaml

def sysrc(key,val=None):
    if val:
        subprocess.run(['/usr/sbin/sysrc','{}={}'.format(key,val)],check=True)
    else:
        subprocess.run(['/usr/sbin/sysrc',key],check=True)

def runrc(name,check=True):
    subprocess.run(['/usr/sbin/service',name,'start'],check=check)
    
r = requests.get('http://169.254.169.254/hetzner/v1/metadata')

if r.status_code != 200:
    raise ValueError("Error fetching cloud-config")

config = yaml.safe_load(r.text)

for k,v in config.items():
    if k == "vendor_data":
        vendor_data_mime = config.get('vendor_data','')
        vendor_data = email.message_from_string(vendor_data_mime)
        for p in vendor_data.walk():
            if not p.is_multipart():
                name = p.get_filename()
                with open(name,"w") as f:
                    f.write(p.get_payload())
                    f.write("\n")
    else:
        # Save config section 
        with open(k,'w') as f:
            json.dump(config.get(k),f,indent=4)
            f.write("\n")
        # Handle config section
        if k == 'hostname':
            sysrc('hostname',v)
            runrc('hostname')
        elif k == 'public-keys':
            sshdir = pathlib.Path('/root/.ssh')
            sshdir.mkdir(mode=0o700,exist_ok=True)
            ak = sshdir / 'authorized_keys'
            with ak.open('w') as f:
                for sshkey in v:
                    f.write(sshkey)
                    f.write('\n')
            ak.chmod(0o600)
        elif k == 'network-config':
            for iface in v['config']:
                ifname = iface['name'].replace('eth','vtnet')
                for subnet in iface['subnets']:
                    if subnet.get('ipv4',False):
                        if subnet['type'] == 'dhcp':
                            sysrc('ifconfig_{}'.format(ifname),'DHCP')
                    elif subnet.get('ipv6',False):
                        if subnet['type'] == 'static':
                            address,prefix = subnet['address'].split('/')
                            sysrc('ifconfig_{}_ipv6'.format(ifname),
                                        'inet6 {} prefixlen {}'.format(address,prefix))
                        if 'gateway' in subnet:
                            sysrc('ipv6_defaultrouter',subnet['gateway'].replace('eth','vtnet'))
            runrc('netif')
            runrc('routing',False)  # Ignore errors from existing routes

