"""Generate local-only credentials. Never prints passwords or overwrites a file."""
import argparse
import ipaddress
import os
import re
import secrets

parser = argparse.ArgumentParser()
parser.add_argument('--domain', required=True)
parser.add_argument('--allowed-ip', action='append', required=True)
parser.add_argument('--output', default='.env.homolog')
args = parser.parse_args()
if not re.fullmatch(r'[a-zA-Z0-9.-]+', args.domain):
    parser.error('Use a hostname without scheme, path or spaces')
for address in args.allowed_ip:
    network = ipaddress.ip_network(address, strict=False)
    if network.prefixlen == 0:
        parser.error('The pilot must not allow the entire internet')
values = {'APP_DOMAIN': args.domain, 'PILOT_ALLOWED_IPS': ' '.join(args.allowed_ip)}
for key in ('DB_PASSWORD', 'DB_ROOT_PASSWORD', 'SECRET_KEY', 'MFA_SECRET_KEY'):
    values[key] = secrets.token_hex(32)
fd = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
with os.fdopen(fd, 'w') as output:
    output.write('\n'.join(f'{key}={value}' for key, value in values.items()) + '\n')
print(f'Environment created: {args.output} (permissions 0600)')
