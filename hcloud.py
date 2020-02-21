#!/usr/local/bin/python3

import requests
import json
import yaml
import email

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
		with open(k,"w") as f:
			json.dump(config.get(k),f,indent=4)
			f.write("\n")
