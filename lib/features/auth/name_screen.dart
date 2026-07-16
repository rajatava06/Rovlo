import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/widgets/onboarding_scaffold.dart';
import '../../providers/auth_provider.dart';

/// Profile step: capture the user's name.
class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final existing = context.read<AuthProvider>().currentUser?.name ?? '';
    _controller = TextEditingController(text: existing);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 2;

  Future<void> _continue() async {
    await context.read<AuthProvider>().setName(_controller.text);
    if (!mounted) return;
    Navigator.pushNamed(context, Routes.gender);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      totalSteps: 5,
      title: 'What should we call you?',
      subtitle: 'This is the name fellow travellers and hosts will see.',
      continueEnabled: _valid,
      onContinue: _continue,
      child: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _valid ? _continue() : null,
        decoration: const InputDecoration(
          hintText: 'Your name',
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
    );
  }
}
