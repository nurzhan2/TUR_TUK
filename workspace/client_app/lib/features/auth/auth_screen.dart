import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/controller_state.dart';
import '../../core/content/app_content.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import 'register_screen.dart';

/// Вход по номеру телефона: два шага в одном экране.
///
/// `PageView` без свайпа, а не два маршрута: шаг «код» бессмысленен без
/// телефона с предыдущего шага, и системная кнопка «назад» на нём должна
/// возвращать к номеру, а не выкидывать из входа.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _pageController = PageController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _goToCode() async {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 11) return;
    await context.read<AuthController>().sendCode('+$digits');
    if (!mounted) return;
    await _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _backToPhone() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  /// Код принят. Профиля нет — сначала анкета, иначе сразу в каталог.
  Future<void> _onVerified() async {
    final auth = context.read<AuthController>();
    if (auth.profile == null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
      if (!mounted) return;
    }
    if (!mounted) return;
    context.go(AppRoutes.catalog);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _PhoneStep(controller: _phoneController, onSubmit: _goToCode),
            _CodeStep(onBack: _backToPhone, onVerified: _onVerified),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- шаг 1

class _PhoneStep extends StatefulWidget {
  const _PhoneStep({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final Future<void> Function() onSubmit;

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  bool get _isComplete =>
      widget.controller.text.replaceAll(RegExp(r'\D'), '').length >= 11;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final loading = context.watch<AuthController>().state.isLoading;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          Text(l10n.authTitle, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            l10n.authSubtitle,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textMuted, fontSize: 15),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: widget.controller,
            keyboardType: TextInputType.phone,
            autofocus: false,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            inputFormatters: [PhoneInputFormatter()],
            decoration: InputDecoration(hintText: l10n.authPhone),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isComplete && !loading ? widget.onSubmit : null,
            child: loading ? const _ButtonSpinner() : Text(l10n.authGetCode),
          ),
          const Spacer(),
          // Ссылка на политику — из админки (Настройки → Контакты). Без
          // открывающейся политики App Store и Google Play не пропустят.
          Builder(builder: (context) {
            final policy = AppContent.instance.contacts.privacyPolicyUrl;
            const style = TextStyle(fontSize: 12, color: AppColors.textMuted);
            if (policy.isEmpty) {
              return const Text(
                'Нажимая «Получить код», вы соглашаетесь с условиями сервиса '
                'и политикой обработки персональных данных',
                textAlign: TextAlign.center,
                style: style,
              );
            }
            return GestureDetector(
              onTap: () => launchUrl(Uri.parse(policy), mode: LaunchMode.externalApplication),
              child: const Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    TextSpan(text: 'Нажимая «Получить код», вы соглашаетесь с условиями сервиса и '),
                    TextSpan(
                      text: 'политикой обработки персональных данных',
                      style: TextStyle(decoration: TextDecoration.underline, color: AppColors.accent),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Маска `+7 (999) 123-45-67`.
///
/// Пакета маски в зависимостях нет, а тянуть его ради одного поля дороже,
/// чем тридцать строк здесь. Форматтер работает по цифрам, а не по позиции
/// курсора: при вставке номера из буфера скобки и дефисы из чужого формата
/// просто отбрасываются.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();

    // Гостья набирает «8 999…» или «+7 999…» — приводим к одному виду.
    if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
    if (!digits.startsWith('7')) digits = '7$digits';
    if (digits.length > 11) digits = digits.substring(0, 11);

    final buffer = StringBuffer('+7');
    if (digits.length > 1) {
      buffer.write(' (${digits.substring(1, digits.length.clamp(1, 4))}');
    }
    if (digits.length >= 4) {
      buffer.write(')');
    }
    if (digits.length > 4) {
      buffer.write(' ${digits.substring(4, digits.length.clamp(4, 7))}');
    }
    if (digits.length > 7) {
      buffer.write('-${digits.substring(7, digits.length.clamp(7, 9))}');
    }
    if (digits.length > 9) {
      buffer.write('-${digits.substring(9)}');
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ---------------------------------------------------------------- шаг 2

class _CodeStep extends StatefulWidget {
  const _CodeStep({required this.onBack, required this.onVerified});

  final VoidCallback onBack;
  final Future<void> Function() onVerified;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  static const _length = 4;
  static const _resendSeconds = 45;

  final _controllers = List.generate(_length, (_) => TextEditingController());
  final _nodes = List.generate(_length, (_) => FocusNode());

  Timer? _resendTimer;
  int _secondsLeft = _resendSeconds;
  bool _invalid = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Рамка активного поля рисуется по `hasFocus`, а переход фокуса сам по
    // себе перестройки не вызывает: без слушателя бордовая рамка стояла бы
    // на первом поле весь ввод.
    for (final node in _nodes) {
      node.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.removeListener(_onFocusChanged);
      n.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _onDigit(int index, String value) async {
    if (_invalid) setState(() => _invalid = false);

    if (value.isNotEmpty && index < _length - 1) {
      _nodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
    if (_code.length == _length) await _verify();
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    _nodes.last.unfocus();
    final ok = await context.read<AuthController>().verifyCode(_code);
    if (!mounted) return;
    setState(() => _checking = false);

    if (ok) {
      await widget.onVerified();
      return;
    }
    // Неверный код — обычный исход формы, а не ошибка загрузки: подсвечиваем
    // поля и даём набрать заново, без экрана «повторить».
    setState(() => _invalid = true);
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final phone = context.watch<AuthController>().phone ?? '';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.authCode, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                phone,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
              ),
              TextButton(
                onPressed: widget.onBack,
                child: Text(l10n.profileEdit),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_length, (i) => _digitBox(i)),
          ),
          if (_invalid) ...[
            const SizedBox(height: 14),
            Text(
              l10n.authInvalidCode,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ],
          const SizedBox(height: 28),
          if (_checking)
            const Center(child: CircularProgressIndicator())
          else if (_secondsLeft > 0)
            Text(
              l10n.authResend(_secondsLeft),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            )
          else
            TextButton(
              onPressed: () {
                context.read<AuthController>().sendCode(phone);
                _startResendTimer();
              },
              child: Text(l10n.authGetCode),
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _digitBox(int index) {
    final focused = _nodes[index].hasFocus;
    final borderColor = _invalid
        ? AppColors.error
        : focused
        ? AppColors.accent
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        width: 56,
        height: 56,
        // Backspace на УЖЕ пустом поле должен уводить фокус назад и стирать
        // предыдущую цифру. Через `onChanged` этот случай не поймать: текст
        // не менялся, значит и события нет.
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey != LogicalKeyboardKey.backspace) {
              return KeyEventResult.ignored;
            }
            if (index == 0 || _controllers[index].text.isNotEmpty) {
              return KeyEventResult.ignored;
            }
            _controllers[index - 1].clear();
            _nodes[index - 1].requestFocus();
            return KeyEventResult.handled;
          },
          child: TextField(
            controller: _controllers[index],
            focusNode: _nodes[index],
            autofocus: index == 0,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              contentPadding: EdgeInsets.zero,
              // Обе рамки заданы явно: тема подставляет в `focusedBorder`
              // бордовый, и покрасневшее поле снова становилось бы бордовым
              // при первом же касании — то есть ошибка исчезала бы с экрана
              // раньше, чем её прочитают.
              enabledBorder: _boxBorder(borderColor),
              focusedBorder: _boxBorder(
                _invalid ? AppColors.error : AppColors.accent,
              ),
            ),
            onChanged: (value) => _onDigit(index, value),
          ),
        ),
      ),
    );
  }
}

OutlineInputBorder _boxBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppSizes.radius),
  borderSide: BorderSide(color: color, width: 1.5),
);

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
