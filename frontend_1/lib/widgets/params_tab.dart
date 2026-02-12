import 'package:flutter/material.dart';

class ParamsTab extends StatefulWidget {
  const ParamsTab({Key? key}) : super(key: key);

  @override
  State<ParamsTab> createState() => _ParamsTabState();
}

class _ParamsTabState extends State<ParamsTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Params Tab'));
  }
}
