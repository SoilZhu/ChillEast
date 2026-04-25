import 'package:flutter/material.dart';

class OssLicensesScreen extends StatelessWidget {
  const OssLicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('开源声明', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          const Text(
            '自在东湖 是基于开源社区的各种优秀组件构建而成的。我们尊重并感谢每一位开发者的贡献。',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          _buildLicenseSection(
            'Flutter SDK',
            'Copyright 2014 The Flutter Authors. All rights reserved. Licensed under the BSD-style license.',
          ),
          _buildLicenseSection(
            'InAppWebView',
            'Copyright (c) 2018 Lorenzo Pichilli. Licensed under the Apache License, Version 2.0.',
          ),
          _buildLicenseSection(
            'Riverpod',
            'Copyright (c) 2020 Remi Rousselet. Licensed under the MIT License.',
          ),
          _buildLicenseSection(
            'Dio',
            'Copyright (c) 2018-2023 getflutter. Licensed under the MIT License.',
          ),
          _buildLicenseSection(
            'BeautifulSoup (Inspirit)',
            'Adapted for HTML parsing logic. Licensed under the MIT License.',
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
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
