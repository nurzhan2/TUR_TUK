import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/cart_controller.dart';
import '../../controllers/catalog_controller.dart';
import '../../controllers/controller_state.dart';
import '../../core/content/app_content.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/category.dart';
import 'widgets/product_card.dart';

/// Витрина: поиск, категории, промо-баннер и сетка товаров.
///
/// Это первый экран, который увидит заказчица, поэтому он собран одним
/// `CustomScrollView`: шапка, поиск и баннер уезжают вверх вместе с
/// товарами. Прибитый `AppBar` над прокруткой съедал бы восьмую часть
/// экрана телефона там, где должны быть фотографии.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final TextEditingController _searchInput = TextEditingController();
  final PageController _bannerPage = PageController();

  Timer? _searchDebounce;
  Timer? _bannerTimer;

  int _bannerIndex = 0;

  @override
  void initState() {
    super.initState();

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), _nextBanner);

    // Загрузка после первого кадра, а не прямо в initState: `load()`
    // синхронно зовёт notifyListeners, а менять провайдер во время сборки
    // дерева нельзя — Flutter бросит setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CatalogController>().load();
      // Корзину не грузит никто другой, а бейдж и степперы карточек
      // читают именно её.
      final cart = context.read<CartController>();
      if (!cart.state.isLoaded) cart.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _bannerTimer?.cancel();
    _bannerPage.dispose();
    _searchInput.dispose();
    super.dispose();
  }

  void _nextBanner(Timer timer) {
    if (!mounted || !_bannerPage.hasClients) return;
    final next = (_bannerIndex + 1) % _promoSlides.length;
    _bannerPage.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  /// Debounce 350 мс: без него «лукум» — это пять перезагрузок списка
  /// подряд, сетка дёргается на каждой букве, а последним на экране может
  /// остаться результат по «лук».
  void _onSearchChanged(String value) {
    setState(() {}); // крестик очистки появляется и исчезает сразу
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      context.read<CatalogController>().search(value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchInput.clear();
    setState(() {});
    context.read<CatalogController>().search('');
  }

  /// Сброс из пустого состояния: снимается и строка поиска, и категория —
  /// человек нажимает «показать всё», а не «убрать одно из двух».
  Future<void> _resetFilters() async {
    _searchDebounce?.cancel();
    _searchInput.clear();
    setState(() {});
    final catalog = context.read<CatalogController>();
    catalog.searchQuery = '';
    await catalog.selectCategory(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = context.watch<CatalogController>();

    final selected = catalog.selectedCategoryId;
    final sectionTitle = _sectionTitle(catalog, l10n);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          onRefresh: () => context.read<CatalogController>().load(),
          child: CustomScrollView(
            // always, а не по содержимому: без прокрутки не сработает
            // «потянуть, чтобы обновить» на состоянии ошибки и на пустом
            // результате поиска.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    4,
                    AppSizes.pagePadding,
                    12,
                  ),
                  child: _SearchField(
                    controller: _searchInput,
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                  ),
                ),
              ),
              if (catalog.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: _CategoryChips(
                    categories: catalog.categories,
                    selectedId: selected,
                    onSelect: (id) =>
                        context.read<CatalogController>().selectCategory(id),
                  ),
                ),
              // Баннеров в админке может не быть — тогда блок не рисуется.
              if (_promoSlides.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PromoBanner(
                    controller: _bannerPage,
                    index: _bannerIndex,
                    onChanged: (index) => setState(() => _bannerIndex = index),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    20,
                    AppSizes.pagePadding,
                    12,
                  ),
                  child: Text(
                    sectionTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              _buildContent(context, catalog, l10n),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  /// Заголовок секции: «Популярное» или название выбранной категории.
  /// Категория может не найтись, если фильтр выставили до того, как
  /// приехал список категорий, — тогда честнее показать «Популярное»,
  /// чем пустую строку.
  String _sectionTitle(CatalogController catalog, AppLocalizations l10n) {
    final selected = catalog.selectedCategoryId;
    if (selected == null) return l10n.popular;
    for (final category in catalog.categories) {
      if (category.id == selected) return category.name;
    }
    return l10n.popular;
  }

  Widget _buildContent(
    BuildContext context,
    CatalogController catalog,
    AppLocalizations l10n,
  ) {
    if (catalog.state.isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        sliver: SliverGrid(
          gridDelegate: _gridDelegate,
          delegate: SliverChildBuilderDelegate(
            (context, index) => const _SkeletonCard(),
            childCount: 6,
          ),
        ),
      );
    }

    if (catalog.state.isError) {
      return SliverToBoxAdapter(
        child: _CatalogMessage(
          icon: Icons.wifi_off_outlined,
          message: catalog.errorMessage ?? l10n.loadingError,
          actionLabel: l10n.retry,
          onAction: () => context.read<CatalogController>().load(),
        ),
      );
    }

    if (catalog.products.isEmpty) {
      return SliverToBoxAdapter(
        child: _CatalogMessage(
          icon: Icons.search_off_outlined,
          message: l10n.catalogEmpty,
          actionLabel: l10n.categoriesAll,
          onAction: _resetFilters,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      sliver: SliverGrid(
        gridDelegate: _gridDelegate,
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: catalog.products[index]),
          childCount: catalog.products.length,
        ),
      ),
    );
  }
}

const SliverGridDelegateWithFixedCrossAxisCount _gridDelegate =
    SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
      childAspectRatio: 0.58,
    );

/// Шапка вместо `AppBar` — уезжает вместе с содержимым.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = AppContent.instance.brand;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 8, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Название и обещание — из настроек админки.
                Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                if (brand.deliveryPromise.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    brand.deliveryPromise,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.chatTitle,
            icon: const Icon(Icons.chat_bubble_outline),
            color: AppColors.textPrimary,
            onPressed: () => context.push(AppRoutes.chat),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: l10n.searchHint,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.textMuted),
                onPressed: onClear,
              ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
        itemCount: categories.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CategoryChip(
              label: l10n.categoriesAll,
              active: selectedId == null,
              onTap: () => onSelect(null),
            );
          }
          final category = categories[index - 1];
          return _CategoryChip(
            label: category.name,
            icon: category.icon,
            active: selectedId == category.id,
            onTap: () => onSelect(category.id),
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? Colors.white : AppColors.textPrimary;

    return Material(
      color: active ? AppColors.accent : AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Слайд промо-баннера. Тексты задаются в админке (Настройки → Баннеры).
class _PromoSlide {
  const _PromoSlide(this.title, this.subtitle, this.icon);

  final String title;
  final String subtitle;
  final IconData icon;
}

const List<IconData> _promoIcons = [
  Icons.local_offer_outlined,
  Icons.local_shipping_outlined,
  Icons.cake_outlined,
  Icons.spa_outlined,
  Icons.beach_access_outlined,
  Icons.card_giftcard_outlined,
];

List<_PromoSlide> get _promoSlides => [
      for (final (i, banner) in AppContent.instance.banners.indexed)
        _PromoSlide(banner.title, banner.subtitle, _promoIcons[i % _promoIcons.length]),
    ];

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({
    required this.controller,
    required this.index,
    required this.onChanged,
  });

  final PageController controller;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            onPageChanged: onChanged,
            itemCount: _promoSlides.length,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pagePadding,
              ),
              child: _PromoCard(slide: _promoSlides[i]),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _promoSlides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == index ? 1 : 0.5,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.slide});

  final _PromoSlide slide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accentDark],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Крупная полупрозрачная иконка справа: баннер без картинки
          // выглядит как пустая заливка с текстом.
          Positioned(
            right: -14,
            bottom: -14,
            child: Icon(
              slide.icon,
              size: 120,
              color: Colors.white.withValues(alpha: 0.13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 96, 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slide.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  slide.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Скелетон карточки: повторяет её раскладку, чтобы сетка не прыгала в
/// момент, когда данные приехали.
///
/// Тикер живёт ВНУТРИ скелетона, а не на экране: контроллер уровня экрана
/// крутился бы вечно и после загрузки — планировал бы кадры для анимации,
/// которой на экране уже нет. Все шесть скелетонов появляются в одном
/// кадре и потому пульсируют синхронно.
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AspectRatio(
              aspectRatio: 1,
              child: ColoredBox(color: AppColors.surface),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SkeletonBar(height: 14, widthFactor: 0.5),
                    const SizedBox(height: 8),
                    const _SkeletonBar(height: 10, widthFactor: 1),
                    const SizedBox(height: 6),
                    const _SkeletonBar(height: 10, widthFactor: 0.7),
                    const Spacer(),
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSizes.radiusSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.height, required this.widthFactor});

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

/// Общий вид «пусто» и «ошибка»: иконка, объяснение, одно действие.
class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
