import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/catalog_controller.dart';
import '../../core/content/app_content.dart';
import '../../core/di.dart';
import '../../core/format.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/product.dart';
import '../catalog/widgets/cart_action_button.dart';
import '../catalog/widgets/product_card.dart';

/// Карточка товара: большое фото, цена, описание и похожие товары.
///
/// Сигнатура задана роутером (`ProductScreen(productId: int)`) и меняться
/// не может: сюда приходят и по тапу из витрины, и прямой ссылкой
/// `/catalog/product/7`.
class ProductScreen extends StatefulWidget {
  const ProductScreen({required this.productId, super.key});

  final int productId;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Product? _product;
  bool _loading = false;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    // После первого кадра: `context.read` до монтирования дерева недоступен,
    // а грузить товар в `build` значит грузить его на каждую перерисовку.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  /// Сначала кеш каталога, и только потом запрос.
  ///
  /// Пришли из витрины — товар уже загружен, и карточка открывается без
  /// единой миллисекунды спиннера. Запрос нужен только для прямой ссылки
  /// или после перезагрузки страницы.
  Future<void> _resolve() async {
    if (!mounted) return;

    final cached = context.read<CatalogController>().cached(widget.productId);
    if (cached != null) {
      setState(() => _product = cached);
      return;
    }

    setState(() => _loading = true);
    try {
      final loaded = await Di.catalog.product(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = loaded;
        _loading = false;
      });
    } catch (_) {
      // Товара нет — это обычный исход для битой ссылки, а не авария:
      // показываем «не найдено» с кнопкой назад.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  /// До шести товаров той же категории, кроме текущего.
  List<Product> _similar(Product product) {
    final result = <Product>[];
    for (final other in context.read<CatalogController>().products) {
      if (other.id == product.id) continue;
      if (other.categoryId != product.categoryId) continue;
      result.add(other);
      if (result.length == 6) break;
    }
    return result;
  }

  void _onAdded(Product product) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${product.name} — ${l10n.productInCart}'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: l10n.addToCart,
          textColor: Colors.white,
          onPressed: () => context.push(AppRoutes.cart),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    if (product == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: _loading || !_notFound
              ? const Center(child: CircularProgressIndicator())
              : const _NotFound(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _Body(product: product, similar: _similar(product)),
          // Кнопка «назад» лежит НАД прокруткой, а не в SliverAppBar:
          // шапка с фото не прибита и уезжает вверх, а уйти с карточки
          // нужно уметь с любой позиции скролла.
          Positioned(
            left: AppSizes.pagePadding,
            top: MediaQuery.of(context).padding.top + 12,
            child: const _BackCircle(),
          ),
        ],
      ),
      bottomNavigationBar: _BuyBar(
        product: product,
        onAdded: () => _onAdded(product),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.product, required this.similar});

  final Product product;
  final List<Product> similar;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 340,
          pinned: false,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: ProductPhoto(
              product: product,
              radius: 0,
              showBadges: false,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding,
              20,
              AppSizes.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.unit,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                _PriceBlock(product: product),
                const SizedBox(height: 18),
                const _DeliveryNote(),
                const SizedBox(height: 24),
                Text(
                  l10n.productDescriptionTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  product.description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (similar.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                28,
                AppSizes.pagePadding,
                12,
              ),
              child: Text(
                l10n.productSimilar,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          SliverToBoxAdapter(child: _SimilarRow(products: similar)),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

/// Лента похожих товаров. Высота фиксирована: карточка внутри тянется
/// `Expanded`, и без явной высоты горизонтальный список её не ограничит.
class _SimilarRow extends StatelessWidget {
  const _SimilarRow({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 268,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        itemCount: products.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => SizedBox(
          width: 150,
          child: ProductCard(product: products[index], compact: true),
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          money(product.price),
          style: const TextStyle(
            fontSize: 26,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        if (product.hasDiscount) ...[
          const SizedBox(width: 10),
          Text(
            money(product.oldPrice!),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textMuted,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          DiscountBadge(percent: product.discountPercent),
        ],
      ],
    );
  }
}

/// Плашка доставки — единственное место карточки, где акцентный фон
/// уместен: это обещание, ради которого приложение и открывают.
class _DeliveryNote extends StatelessWidget {
  const _DeliveryNote();

  @override
  Widget build(BuildContext context) {
    // Срок — из настроек админки (Настройки → Время доставки).
    final eta = AppContent.instance.delivery.etaMinutes;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppSizes.radiusSmall),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 22,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Доставка на рецепцию отеля за $eta минут',
              style: const TextStyle(
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Белый круг с тенью вместо системной стрелки: на светлом фото товара
/// (лукум, полотенце, крем) чёрная стрелка на прозрачном фоне не видна.
class _BackCircle extends StatelessWidget {
  const _BackCircle();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (context.canPop()) {
            context.pop();
          } else {
            // Прямая ссылка на товар: возвращаться некуда, уводим в каталог.
            context.go(AppRoutes.catalog);
          }
        },
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.arrow_back, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Нижняя панель покупки: цена слева, кнопка или степпер справа.
class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.product, required this.onAdded});

  final Product product;
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            12,
            AppSizes.pagePadding,
            12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      money(product.price),
                      style: const TextStyle(
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (product.hasDiscount)
                      Text(
                        money(product.oldPrice!),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 190,
                child: CartActionButton(
                  product: product,
                  height: 48,
                  fontSize: 15,
                  label: l10n.productToCart,
                  onAdded: onAdded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Товара нет — экран не падает и предлагает вернуться.
class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.remove_shopping_cart_outlined,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          // TODO l10n: нет подходящего ключа среди заведённых 93.
          const Text(
            'Товар не найден',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 220,
            child: OutlinedButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.catalog),
              child: Text(l10n.close),
            ),
          ),
        ],
      ),
    );
  }
}
