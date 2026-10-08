#!/usr/bin/env python3
"""Parse IPv4 destinations from *all* Linux policy-routing tables.

Input: ip -4 -o route show table all. Ignores the default route but blocks
local/broadcast/connected/policy routes and single-host address routes.
"""
import ipaddress
import sys

PREFIXED = {'local', 'broadcast', 'anycast', 'unicast', 'nat'}
IGNORE = {'default', 'blackhole', 'unreachable', 'prohibit', 'throw'}
routes = set()
for line in sys.stdin:
    tokens = line.split()
    if not tokens:
        continue
    first = 1 if tokens[0] in PREFIXED else 0
    if len(tokens) <= first:
        continue
    cidr = tokens[first]
    if cidr in IGNORE:
        continue
    try:
        ip = ipaddress.ip_network(cidr, strict=False)
    except ValueError:
        continue
    if ip.version == 4:
        routes.add(str(ip))
for network in ipaddress.collapse_addresses(ipaddress.ip_network(cidr) for cidr in routes):
    print(network)
