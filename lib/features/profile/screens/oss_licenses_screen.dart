import 'package:flutter/material.dart';
import '../../../core/utils/l10n_extension.dart';

class OssLicensesScreen extends StatelessWidget {
  const OssLicensesScreen({super.key});

  static const List<Map<String, String>> _dependencies = [
    {
      'title': 'Flutter SDK',
      'content': 'Copyright 2014 The Flutter Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Flutter Localizations',
      'content': 'Copyright 2014 The Flutter Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Cupertino Icons',
      'content': 'Copyright (c) 2016 Vladimir Kharlampidi. Licensed under the MIT License.',
    },
    {
      'title': 'Flutter SVG',
      'content': 'Copyright (c) 2018 Dan Field. Licensed under the MIT License.',
    },
    {
      'title': 'Riverpod (flutter_riverpod & riverpod_annotation)',
      'content': 'Copyright (c) 2020 Remi Rousselet. Licensed under the MIT License.',
    },
    {
      'title': 'Dio & dio_cookie_manager',
      'content': 'Copyright (c) 2018 Wen Du (wendux), Copyright (c) 2022 The CFUG Team. Licensed under the MIT License.',
    },
    {
      'title': 'CookieJar',
      'content': 'Copyright (c) 2018 wendux. Licensed under the MIT License.',
    },
    {
      'title': 'Flutter InAppWebView',
      'content': 'Copyright (c) 2018 Lorenzo Pichilli. Licensed under the Apache License, Version 2.0.',
    },
    {
      'title': 'Flutter Secure Storage',
      'content': 'Copyright 2017 German Saprykin. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Encrypt',
      'content': 'Copyright (c) 2018, Leo Cavalcante. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'PointyCastle',
      'content': 'Copyright (c) 2000 - 2019 The Legion of the Bouncy Castle Inc. Licensed under the MIT License.',
    },
    {
      'title': 'Crypto',
      'content': 'Copyright 2015, the Dart project authors. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Shared Preferences',
      'content': 'Copyright 2013 The Flutter Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'HTML Parser (html)',
      'content': 'Copyright (c) 2006-2012 The Authors. Licensed under the MIT License.',
    },
    {
      'title': 'iCalendar Parser',
      'content': 'Copyright (c) 2021 Guillaume Roux. Licensed under the MIT License.',
    },
    {
      'title': 'Path Provider',
      'content': 'Copyright 2013 The Flutter Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Path',
      'content': 'Copyright 2014, the Dart project authors. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Share Plus',
      'content': 'Copyright 2017, the Flutter project authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'File Picker',
      'content': 'Copyright (c) 2018 Miguel Ruivo. Licensed under the MIT License.',
    },
    {
      'title': 'Permission Handler',
      'content': 'Copyright (c) 2018 Baseflow. Licensed under the MIT License.',
    },
    {
      'title': 'Intl',
      'content': 'Copyright 2013, the Dart project authors. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Logger',
      'content': 'Copyright (c) 2019 Simon Leier. Licensed under the MIT License.',
    },
    {
      'title': 'Geolocator',
      'content': 'Copyright (c) 2018 Baseflow. Licensed under the MIT License.',
    },
    {
      'title': 'Flutter Local Notifications',
      'content': 'Copyright 2018 Michael Bui. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Workmanager',
      'content': 'Copyright (c) 2019 vrtdev, Copyright (c) 2023 Flutter Community. Licensed under the MIT License.',
    },
    {
      'title': 'Timezone',
      'content': 'Copyright (c) 2014, timezone project authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Flutter Native Splash',
      'content': 'Copyright (c) 2022 Jon Hanson. Licensed under the MIT License.',
    },
    {
      'title': 'URL Launcher',
      'content': 'Copyright 2013 The Flutter Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Mobile Scanner',
      'content': 'Copyright (c) 2022, Julian Steenbakker. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Image Picker (image_picker, android & platform)',
      'content': 'Copyright 2013 The Flutter Authors. All rights reserved. Licensed under the Apache License, Version 2.0 / BSD 3-Clause License.',
    },
    {
      'title': 'Package Info Plus',
      'content': 'Copyright 2017 The Chromium Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Android Package Installer',
      'content': 'Copyright (c) 2022, Rovshan Gurbanov. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Flutter Markdown',
      'content': 'Copyright 2013 The Flutter Authors. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'Fast GBK',
      'content': 'Copyright 2019, LI Xiang. All rights reserved. Licensed under the BSD 3-Clause License.',
    },
    {
      'title': 'BeautifulSoup (Inspirit)',
      'content': 'Adapted for HTML parsing logic. Licensed under the MIT License.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l10n.openSourceLicenses, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            context.l10n.ossDescription,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ..._dependencies.map((dep) => _buildLicenseSection(dep['title']!, dep['content']!)),
        ],
      ),
    );
  }

  Widget _buildLicenseSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
