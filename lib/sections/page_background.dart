import 'package:flutter/material.dart';

class PageBackground extends StatelessWidget {
  const PageBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: child);
  }
}
