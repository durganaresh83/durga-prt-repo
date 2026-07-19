import json
import subprocess
import urllib.request
from pathlib import Path

cmd = [
    'powershell',
    '-NoProfile',
    '-Command',
    'aws eks update-kubeconfig --region us-east-1 --name microservices-dev; '
    '$url=kubectl get svc frontend-svc -n fullstack-app -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"; '
    'Write-Host "FRONTEND_URL=http://$url"; '
    'Write-Host "SERVICE_HOST=$url"'
]
proc = subprocess.run(cmd, capture_output=True, text=True)
print(proc.stdout)
if proc.returncode != 0:
    print(proc.stderr)
    raise SystemExit(proc.returncode)

# Try to extract the host from stdout
host = None
for line in proc.stdout.splitlines():
    if line.startswith('SERVICE_HOST='):
        host = line.split('=', 1)[1].strip()
        break
if not host:
    raise SystemExit('Could not determine frontend host')
url = f'http://{host}'
print('URL=' + url)
for path in ['', '/api/hello']:
    target = url + path
    print('REQUEST ' + target)
    req = urllib.request.Request(target, headers={'User-Agent': 'curl/7.0'})
    with urllib.request.urlopen(req, timeout=30) as r:
        body = r.read().decode('utf-8')
        print('STATUS', r.status)
        print(body[:800])
        print('---')
