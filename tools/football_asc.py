"""Read-only App Store Connect inventory; credentials are supplied through env."""
import base64
import json
import os
import time
import urllib.request
import subprocess
import sys

from cryptography import x509
from cryptography.hazmat.primitives import serialization

import jwt

key = base64.b64decode(os.environ["APPLE_API_KEY_P8_BASE64"])
token = jwt.encode({"iss": os.environ["APPLE_API_ISSUER_ID"], "aud": "appstoreconnect-v1", "exp": int(time.time()) + 600}, key, algorithm="ES256", headers={"kid": os.environ["APPLE_API_KEY_ID"]})

def get(path):
    request = urllib.request.Request("https://api.appstoreconnect.apple.com/v1/" + path, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(request) as response:
        return json.load(response)

def send(path, payload, method='POST'):
    request = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/' + path, data=json.dumps(payload).encode(), method=method, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(request) as response:
        return json.load(response) if response.status != 204 else None

if '--internal-testflight' in sys.argv:
    number = sys.argv[sys.argv.index('--build') + 1] if '--build' in sys.argv else '4'
    builds = get('builds?filter[app]=6818659764&filter[version]=' + number)['data']
    build = next(item for item in builds if item['attributes']['processingState'] == 'VALID')
    send('builds/' + build['id'], {'data': {'type': 'builds', 'id': build['id'], 'attributes': {'usesNonExemptEncryption': False}}}, 'PATCH')
    groups = get('apps/6818659764/betaGroups')['data']
    internal = [group for group in groups if group['attributes']['isInternalGroup']]
    if not internal:
        group = send('betaGroups', {'data': {'type': 'betaGroups', 'attributes': {'name': 'Equipe interna', 'isInternalGroup': True}, 'relationships': {'app': {'data': {'type': 'apps', 'id': '6818659764'}}}}})['data']
        internal = [group]
    for group in internal:
        send('betaGroups/' + group['id'] + '/relationships/builds', {'data': [{'type': 'builds', 'id': build['id']}]})
        testers = get('betaGroups/' + group['id'] + '/betaTesters')['data']
        print(json.dumps({'group': group['attributes']['name'], 'internal': True, 'buildNumber': number, 'testerCount': len(testers)}))
    print(json.dumps(get('builds/' + build['id'] + '/buildBetaDetail')['data']['attributes']))
    sys.exit(0)

if '--configure-signing' in sys.argv:
    cert_bytes = base64.b64decode(os.environ['APPLE_DISTRIBUTION_CERT_BASE64'])
    cert = x509.load_der_x509_certificate(cert_bytes)
    private_key = serialization.load_pem_private_key(base64.b64decode(os.environ['APPLE_DISTRIBUTION_KEY_BASE64']), password=None)
    assert cert.public_key().public_numbers() == private_key.public_key().public_numbers(), 'Certificate/key mismatch'
    certificates = get('certificates?filter[certificateType]=IOS_DISTRIBUTION')['data']
    selected = next(item for item in certificates if int(item['attributes']['serialNumber'], 16) == cert.serial_number)
    payload = {'data': {'type': 'profiles', 'attributes': {'name': 'Tecnico App Store 2026', 'profileType': 'IOS_APP_STORE'}, 'relationships': {'bundleId': {'data': {'type': 'bundleIds', 'id': 'PNWWPVVWRQ'}}, 'certificates': {'data': [{'type': 'certificates', 'id': selected['id']}]}}}}
    request = urllib.request.Request('https://api.appstoreconnect.apple.com/v1/profiles', data=json.dumps(payload).encode(), headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'})
    with urllib.request.urlopen(request) as response:
        profile = json.load(response)['data']['attributes']['profileContent']
    secrets = {'APPLE_API_KEY_P8': key.decode(), 'APPLE_API_KEY_ID': os.environ['APPLE_API_KEY_ID'], 'APPLE_API_ISSUER_ID': os.environ['APPLE_API_ISSUER_ID'], 'APPLE_DISTRIBUTION_CERT': os.environ['APPLE_DISTRIBUTION_CERT_BASE64'], 'APPLE_DISTRIBUTION_KEY': os.environ['APPLE_DISTRIBUTION_KEY_BASE64'], 'APPLE_PROVISIONING_PROFILE': profile}
    for name, value in secrets.items():
        subprocess.run(['gh', 'secret', 'set', name, '--repo', 'socialbot114-cell/ios-app-factory'], input=value.encode(), check=True)
    print('Football signing profile created and GitHub secrets configured.')
    sys.exit(0)

for path in ["apps/6818659764", "apps/6818659764/appStoreVersions", "builds?filter[app]=6818659764&include=preReleaseVersion"]:
    data = get(path)
    print(json.dumps({"endpoint": path, "data": [{"id": item['id'], "attributes": item['attributes']} for item in (data['data'] if isinstance(data['data'], list) else [data['data']])], "included": data.get("included")}, ensure_ascii=False))
