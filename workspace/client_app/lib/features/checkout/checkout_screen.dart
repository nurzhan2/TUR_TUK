import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/orders_controller.dart';
import '../../core/demo/demo_mode.dart';
import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hotel_picker.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/cart.dart';
import '../../models/promo_result.dart';
import '../cart/cart_totals.dart';
import 'kemer_hotels.dart';
import 'order_success_screen.dart';
import 'package:client_app/core/widgets/app_image.dart';

/// Способ оплаты. Наличных нет намеренно: заказчица исключила их из ТЗ —
/// курьер не носит сдачу и не принимает лиры.
enum PaymentMethod { card, sbp }

/// Оформление заказа: доставка, промокод, оплата, состав и итог.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _promoController = TextEditingController();

  String _hotel = '';
  bool _hotelMissing = false;
  PaymentMethod _payment = PaymentMethod.card;

  /// Если товара нет при сборке: replace | remove | call.
  String _ifMissing = 'replace';

  /// Последний ответ на проверку промокода. `null` — промокод не вводили.
  PromoResult? _promo;
  bool _promoLoading = false;

  bool _paying = false;
  bool _itemsExpanded = false;
  bool _roomMissing = false;
  String? _minOrderError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  @override
  void dispose() {
    _roomController.dispose();
    _commentController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  /// Отель и комната из профиля. Профиль подгружаем сами: до чекаута можно
  /// дойти, не проходя экран входа, и тогда `AuthController` ещё пуст.
  Future<void> _prefillFromProfile() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (auth.profile == null) await auth.load();
    if (!mounted) return;
    final profile = auth.profile;
    setState(() {
      _hotel = defaultKemerHotel(profile?.hotelName);
      if (_roomController.text.isEmpty) {
        _roomController.text = profile?.roomNumber ?? '';
      }
    });
  }

  double get _discount =>
      (_promo?.valid ?? false) ? _promo!.discount : 0;

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty || _promoLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _promoLoading = true);
    // Промокоды идут мимо контроллера — своего у них нет, а заводить его
    // ради одного вызова на одном экране не за чем.
    final result = await Di.promo.validate(
      code,
      context.read<CartController>().total,
    );
    if (!mounted) return;
    setState(() {
      _promoLoading = false;
      _promo = result;
    });
  }

  void _clearPromo() {
    setState(() {
      _promo = null;
      _promoController.clear();
    });
  }

  Future<void> _pay(CartTotals totals, AppLocalizations l10n) async {
    if (_paying) return;
    final room = _roomController.text.trim();
    if (totals.belowMinOrder || room.isEmpty || _hotel.isEmpty) {
      setState(() {
        _minOrderError =
            totals.belowMinOrder ? l10n.checkoutMinOrderError : null;
        _roomMissing = room.isEmpty;
        _hotelMissing = _hotel.isEmpty;
      });
      return;
    }

    setState(() {
      _paying = true;
      _minOrderError = null;
      _roomMissing = false;
      _hotelMissing = false;
    });

    final comment = _commentController.text.trim();
    try {
      // Демо: имитация оплаты без ухода в браузер — демо показывают без
      // сети, и переход посреди показа оборвал бы сценарий.
      if (kDemoMode) await Future<void>.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;
      final order = await context.read<OrdersController>().create(
            hotelName: _hotel,
            roomNumber: room,
            promoCode: (_promo?.valid ?? false) ? _promo!.code : null,
            comment: comment.isEmpty ? null : comment,
            paymentMethod: _payment.name,
            ifMissing: _ifMissing,
          );
      if (!mounted) return;
      if (!kDemoMode) {
        // Боевой режим: страница оплаты ЮKassa во встроенном браузере
        // (Custom Tabs / Safari View). Итог оплаты сервер узнаёт вебхуком,
        // а гость после оплаты возвращается в приложение по return_url.
        final url = await Di.payments.confirmationUrl(order.id);
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
        if (!mounted) return;
      }
      await context.read<CartController>().clear();
      if (!mounted) return;
      // Экран успеха ЗАМЕЩАЕТ чекаут: «назад» с него должно вести куда
      // угодно, только не на форму оплаты с уже очищенной корзиной.
      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderSuccessScreen(order: order),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _paying = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.loadingError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cart = context.watch<CartController>().cart;
    final totals = CartTotals(subtotal: cart.total, discount: _discount);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.checkoutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          _deliverySection(l10n),
          const SizedBox(height: AppSizes.gap),
          _promoSection(l10n),
          const SizedBox(height: AppSizes.gap),
          _paymentSection(l10n),
          const SizedBox(height: AppSizes.gap),
          _itemsSection(l10n, cart),
          const SizedBox(height: AppSizes.gap),
          _totalsSection(l10n, totals),
        ],
      ),
      bottomNavigationBar: _payBar(l10n, totals),
    );
  }

  Widget _deliverySection(AppLocalizations l10n) {
    return _SectionCard(
      title: 'Доставка', // TODO l10n
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Поле с поиском: отелей в зоне доставки сотни. Значение — из
          // `_hotel`, который проставляется из профиля после первого кадра.
          HotelPickerField(
            value: _hotel,
            prefixIcon: const Icon(Icons.apartment_outlined),
            errorText: _hotelMissing ? 'Выберите отель' : null,
            onChanged: (value) => setState(() {
              _hotel = value;
              _hotelMissing = false;
            }),
          ),
          const SizedBox(height: AppSizes.gap),
          TextField(
            controller: _roomController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              if (_roomMissing && value.trim().isNotEmpty) {
                setState(() => _roomMissing = false);
              }
            },
            decoration: InputDecoration(
              labelText: l10n.checkoutRoom,
              prefixIcon: const Icon(Icons.meeting_room_outlined),
              errorText: _roomMissing
                  ? 'Укажите номер комнаты' // TODO l10n
                  : null,
            ),
          ),
          const SizedBox(height: AppSizes.gap),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 2,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(labelText: l10n.checkoutComment),
          ),
          const SizedBox(height: AppSizes.gap),
          // Как у Самоката/Лавки: сборщик не гадает и не звонит без нужды.
          const Text(
            'Если товара не окажется',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in const [
                ('replace', 'Заменить похожим'),
                ('remove', 'Убрать из заказа'),
                ('call', 'Позвонить мне'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _ifMissing == value,
                  onSelected: (_) => setState(() => _ifMissing = value),
                  shape: const StadiumBorder(),
                  showCheckmark: false,
                  selectedColor: AppColors.accentSoft,
                  labelStyle: TextStyle(
                    color: _ifMissing == value ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: _ifMissing == value ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.gap),
          const _Hint(
            text: 'Курьер оставит заказ на рецепции — заберёте его по номеру '
                'заказа или последним 4 цифрам телефона', // TODO l10n
          ),
        ],
      ),
    );
  }

  Widget _promoSection(AppLocalizations l10n) {
    final promo = _promo;
    final applied = promo != null && promo.valid;
    // Текст ошибки считаем одним выражением: так `promo` повышается до
    // ненулевого типа там же, где читается его `error`.
    final promoError = promo != null && !promo.valid
        ? (promo.error ?? l10n.checkoutPromoInvalid)
        : null;

    return _SectionCard(
      title: l10n.checkoutPromo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _promoController,
                  // Применённый промокод редактировать нельзя: скидка уже
                  // посчитана по этому коду, и правка поля рассинхронила бы
                  // её с итогом.
                  enabled: !applied,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _applyPromo(),
                  decoration: InputDecoration(
                    hintText: l10n.checkoutPromo,
                    errorText: promoError,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.gap),
              // `minimumSize` перебиваем: в теме у кнопок ширина
              // `Size.fromHeight`, то есть бесконечная, — в строке рядом с
              // полем такая кнопка роняет разметку.
              OutlinedButton(
                onPressed: applied || _promoLoading ? null : _applyPromo,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: _promoLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.checkoutPromoApply),
              ),
            ],
          ),
          if (applied) ...[
            const SizedBox(height: AppSizes.gap),
            _AppliedPromo(
              label: '${l10n.checkoutPromoApplied} · ${promo.code}',
              discount: promo.discount,
              onRemove: _clearPromo,
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentSection(AppLocalizations l10n) {
    return _SectionCard(
      title: 'Оплата', // TODO l10n
      child: RadioGroup<PaymentMethod>(
        groupValue: _payment,
        onChanged: (value) {
          if (value != null) setState(() => _payment = value);
        },
        child: const Column(
          children: [
            _PaymentTile(
              value: PaymentMethod.card,
              icon: Icons.credit_card,
            ),
            _PaymentTile(
              value: PaymentMethod.sbp,
              icon: Icons.qr_code_2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemsSection(AppLocalizations l10n, Cart cart) {
    const previewCount = 3;
    final hidden = cart.items.length - previewCount;
    final visible = _itemsExpanded
        ? cart.items
        : cart.items.take(previewCount).toList(growable: false);

    return _SectionCard(
      title: l10n.orderItems,
      child: InkWell(
        // Разворот по тапу на всю секцию: попадать в маленькую подпись
        // «ещё 4 товара» пальцем неудобно.
        onTap: hidden > 0
            ? () => setState(() => _itemsExpanded = !_itemsExpanded)
            : null,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderLine(item: item),
              ),
            if (hidden > 0)
              Row(
                children: [
                  Text(
                    _itemsExpanded
                        ? 'Свернуть' // TODO l10n
                        : 'ещё ${l10n.cartItems(hidden)}', // TODO l10n
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Icon(
                    _itemsExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _totalsSection(AppLocalizations l10n, CartTotals totals) {
    final theme = Theme.of(context);
    return _SectionCard(
      child: Column(
        children: [
          _SummaryRow(
            label: l10n.checkoutSubtotal,
            value: money(totals.subtotal),
          ),
          if (totals.discount > 0) ...[
            const SizedBox(height: 8),
            _SummaryRow(
              label: l10n.checkoutDiscount,
              value: '−${money(totals.discount)}',
              valueColor: AppColors.accent,
            ),
          ],
          const SizedBox(height: 8),
          _SummaryRow(
            label: l10n.checkoutDelivery,
            value: totals.isDeliveryFree
                ? 'Бесплатно' // TODO l10n
                : money(totals.delivery),
            valueColor: totals.isDeliveryFree ? AppColors.success : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.gap),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.checkoutTotal, style: theme.textTheme.titleMedium),
              Text(money(totals.total), style: theme.textTheme.headlineSmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payBar(AppLocalizations l10n, CartTotals totals) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_minOrderError != null) ...[
                Text(
                  _minOrderError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 8),
              ],
              ElevatedButton(
                onPressed: _paying ? null : () => _pay(totals, l10n),
                child: _paying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textMuted,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(l10n.checkoutPay),
                          Text(money(totals.total)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Карточка секции: бордер вместо тени — как во всей теме приложения.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child, this.title});

  /// `null` — секция без заголовка (итоговый блок: там заголовком служит
  /// сама строка «К оплате»).
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSizes.gap),
          ],
          child,
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.value, required this.icon});

  final PaymentMethod value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (value) {
      PaymentMethod.card => l10n.checkoutPaymentCard,
      PaymentMethod.sbp => l10n.checkoutPaymentSbp,
    };
    return RadioListTile<PaymentMethod>(
      value: value,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.trailing,
      title: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}

class _AppliedPromo extends StatelessWidget {
  const _AppliedPromo({
    required this.label,
    required this.discount,
    required this.onRemove,
  });

  final String label;
  final double discount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.success),
            ),
          ),
          Text(
            '−${money(discount)}',
            style: const TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.success,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 44,
            height: 44,
            child: item.product.imageAsset.isEmpty
                ? const ColoredBox(color: AppColors.surface)
                : AppImage(
                    item.product.imageAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.surface),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            item.product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Text('× ${item.quantity}', style: theme.textTheme.bodySmall),
        const SizedBox(width: 10),
        Text(
          money(item.lineTotal),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 20, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style:
                theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: AppSizes.gap),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
