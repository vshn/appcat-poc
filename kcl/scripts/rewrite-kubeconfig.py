#!/usr/bin/env python3
import sys
import yaml

if len(sys.argv) != 3:
    print("Usage: rewrite-kubeconfig.py <host> <path>")
    sys.exit(1)

host = sys.argv[1]
path = sys.argv[2]

with open(path) as fh:
    data = yaml.safe_load(fh)

for cluster in data.get("clusters", []):
    server = cluster["cluster"]["server"]
    port = server.split(":")[-1]
    cluster["cluster"]["server"] = f"https://{host}:{port}"

with open(path, "w") as fh:
    yaml.safe_dump(data, fh)
