import datetime
import os
import pathlib
import plistlib

root = pathlib.Path(os.environ['RUNNER_TEMP'])
with (root / 'profile.plist').open('rb') as file:
    profile = plistlib.load(file)
team = profile['TeamIdentifier'][0]
assert profile['Entitlements']['application-identifier'] == team + '.' + os.environ['BUNDLE'], 'Wrong provisioning profile'
assert profile['ExpirationDate'] > datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None), 'Expired profile'
assert not profile.get('ProvisionedDevices') and not profile['Entitlements'].get('get-task-allow'), 'Not an App Store profile'
with open(os.environ['GITHUB_ENV'], 'a') as file:
    file.write(f"TEAM={team}\nPROFILE_NAME={profile['Name']}\n")
with (root / 'ExportOptions.plist').open('wb') as file:
    plistlib.dump({'method': 'app-store-connect', 'teamID': team, 'signingStyle': 'manual', 'provisioningProfiles': {os.environ['BUNDLE']: profile['Name']}}, file)
