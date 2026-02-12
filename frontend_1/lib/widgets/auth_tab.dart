import 'package:flutter/material.dart';

class AuthTab extends StatefulWidget {
  const AuthTab({Key? key}) : super(key: key);

  @override
  State<AuthTab> createState() => _AuthTabState();
}

class _AuthTabState extends State<AuthTab> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Auth Tab'));
  }
}
