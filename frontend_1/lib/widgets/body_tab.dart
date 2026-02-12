import 'package:flutter/material.dart';

class BodyTab extends StatefulWidget {
  const BodyTab({Key? key}) : super(key: key);

  @override
  State<BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends State<BodyTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Body Tab'));
  }
}
