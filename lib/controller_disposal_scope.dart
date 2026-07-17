import 'package:flutter/material.dart';

class ControllerDisposalScope extends StatefulWidget {
  const ControllerDisposalScope({
    super.key,
    required this.controllers,
    required this.builder,
  });

  final List<TextEditingController> controllers;
  final WidgetBuilder builder;

  @override
  State<ControllerDisposalScope> createState() =>
      _ControllerDisposalScopeState();
}

class _ControllerDisposalScopeState extends State<ControllerDisposalScope> {
  @override
  Widget build(BuildContext context) => widget.builder(context);

  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
