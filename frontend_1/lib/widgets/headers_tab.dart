import 'package:flutter/material.dart';

class HeadersTab extends StatefulWidget {
  const HeadersTab({Key? key}) : super(key: key);

  @override
  State<HeadersTab> createState() => _HeadersTabState();
}

class _HeadersTabState extends State<HeadersTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Headers Tab'));
  }
}
