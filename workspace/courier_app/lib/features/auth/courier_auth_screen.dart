import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'auth_controller.dart';

/// Экран входа курьера: тот же двухшаговый SMS-контур, что у клиентского
/// приложения (номер телефона -> код из SMS), см. `AuthRepository`.
class CourierAuthScreen extends StatefulWidget {
  const CourierAuthScreen({super.key});

  @override
  State<CourierAuthScreen> createState() => _CourierAuthScreenState();
}

class _CourierAuthScreenState extends State<CourierAuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthController>();

    // Пока `restoreSession()` не вернулся — неизвестно, есть ли уже валидный
    // токен, и показывать форму входа рано: на телефоне с сохранённой сессией
    // это был бы заметный мигающий переход на список заказов сразу после.
    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delivery_dining, size: 64, color: AppColors.bordeaux),
              const SizedBox(height: 16),
              Text(
                l10n.authTitle,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (auth.status == AuthStatus.codeEntry)
                _CodeStep(controller: _codeController, auth: auth, l10n: l10n)
              else
                _PhoneStep(controller: _phoneController, auth: auth, l10n: l10n),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  auth.errorMessage == 'network_error'
                      ? l10n.authGenericError
                      : auth.errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.controller, required this.auth, required this.l10n});

  final TextEditingController controller;
  final AuthController auth;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          enabled: !auth.isLoading,
          decoration: InputDecoration(labelText: l10n.phoneLabel, hintText: l10n.phoneHint),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: auth.isLoading
              ? null
              : () {
                  final phone = controller.text.trim();
                  if (phone.isEmpty) return;
                  auth.sendCode(phone);
                },
          child: auth.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.sendCodeButton),
        ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({required this.controller, required this.auth, required this.l10n});

  final TextEditingController controller;
  final AuthController auth;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(auth.phone, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          enabled: !auth.isLoading,
          decoration: InputDecoration(labelText: l10n.codeLabel, hintText: l10n.codeHint),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: auth.isLoading
              ? null
              : () {
                  final code = controller.text.trim();
                  if (code.isEmpty) return;
                  auth.verifyCode(code);
                },
          child: auth.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(l10n.verifyCodeButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: auth.isLoading ? null : () => auth.sendCode(auth.phone),
          child: Text(l10n.resendCodeButton),
        ),
        TextButton(
          onPressed: auth.isLoading ? null : auth.backToPhoneEntry,
          child: Text(l10n.changePhoneButton),
        ),
      ],
    );
  }
}
