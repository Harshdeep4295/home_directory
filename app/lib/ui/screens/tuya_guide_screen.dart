import 'package:flutter/material.dart';

/// T6.4: how to get Tuya local keys for Wipro / Syska / other Tuya-based devices.
/// Plain copy; nothing here goes online.
class TuyaGuideScreen extends StatelessWidget {
  const TuyaGuideScreen({super.key});

  static const steps = <(String, String)>[
    (
      'Why this is needed',
      'Wipro, Syska and many other brands are Tuya devices. On your Wi-Fi they only '
          'accept commands encrypted with their "local key", which is kept in the '
          'vendor cloud. You get it once, by moving the device into a Smart Life account '
          'that you also link to a free Tuya developer project. After that, control '
          'is fully offline.',
    ),
    (
      '1. Create a Tuya IoT project',
      'On a computer open iot.tuya.com and sign up. Cloud → Development → Create '
          'Cloud Project. Development method "Smart Home", data centre "India" '
          '(or the region your account is in). Add the "IoT Core" API service when '
          'asked. The project Overview shows the Access ID and Access Secret.',
    ),
    (
      '2. Install Smart Life',
      'Install the Smart Life app on your phone and create an account in the same '
          'region.',
    ),
    (
      '3. Re-pair each device into Smart Life',
      'Remove it from the Wipro / Syska app. Reset the device (usually: hold its '
          'button for about 5 seconds until the light blinks fast), then add it in '
          'Smart Life. It keeps working the same, just under your account.',
    ),
    (
      '4. Link Smart Life to the project',
      'In the IoT project: Devices → Link App Account → Add App Account. Scan the '
          'QR code with Smart Life (Me → scan icon at the top). Your devices appear '
          'in the project\'s device list.',
    ),
    (
      '5. Get the keys',
      'Either tap "Import from Tuya cloud" here and enter the Access ID and '
          'Secret, or on a computer run  pip install tinytuya  then  '
          'python -m tinytuya wizard  and send the devices.json it writes to this '
          'phone ("Choose devices.json").',
    ),
    (
      '6. Re-link Alexa (optional)',
      'In the Alexa app enable the Smart Life skill, link your account and discover '
          'devices. Remove the old Wipro / Syska skill devices.',
    ),
    (
      'Keep in mind',
      'Resetting or re-pairing a device gives it a new local key: import again '
          'afterwards. The developer project is only needed while importing; if its '
          'free API access lapses, control from this app keeps working.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Getting Tuya keys')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, body) in steps) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            SelectableText(body),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
