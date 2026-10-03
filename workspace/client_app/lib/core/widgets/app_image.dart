import 'package:flutter/material.dart';

/// Картинка товара, логотипа или баннера из любого источника.
///
/// Контент приходит из админки, и фото там — ссылки (`https://…/media/…`);
/// в демо без сервера — пути в ассетах. Экраны не должны знать, откуда
/// пришла картинка: везде, где раньше был `Image.asset`, теперь `AppImage`.
///
/// Сеть: мягкая заглушка, пока грузится, плавное появление и тот же
/// `errorBuilder`, что у ассетов, — гость в роуминге не видит ни пустых
/// дыр, ни красных экранов ошибок.
class AppImage extends StatelessWidget {
  const AppImage(
    this.source, {
    super.key,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.errorBuilder,
    this.semanticLabel,
    this.cacheWidth,
  });

  final String source;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final AlignmentGeometry alignment;
  final ImageErrorWidgetBuilder? errorBuilder;
  final String? semanticLabel;

  /// Декодировать в уменьшенном размере — экономит память в длинных списках.
  final int? cacheWidth;

  static bool isNetwork(String source) =>
      source.startsWith('http://') || source.startsWith('https://');

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) {
      return errorBuilder?.call(context, 'empty', null) ?? const _Placeholder();
    }
    if (!isNetwork(source)) {
      return Image.asset(
        source,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        errorBuilder: errorBuilder,
        semanticLabel: semanticLabel,
        cacheWidth: cacheWidth,
      );
    }
    return Image.network(
      source,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      semanticLabel: semanticLabel,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: errorBuilder ?? (_, _, _) => const _Placeholder(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          // passthrough: картинка получает размеры родителя (квадрат карточки)
          // и BoxFit.cover заполняет его. Стандартный Stack давал свободные
          // размеры — фото вписывалось в ширину с полосами сверху и снизу.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.passthrough,
            alignment: Alignment.center,
            children: [...previous, ?current],
          ),
          child: frame == null
              ? const _Placeholder(key: ValueKey('loading'))
              : KeyedSubtree(key: const ValueKey('image'), child: child),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ColoredBox(
      color: color.withValues(alpha: 0.6),
      child: const SizedBox.expand(),
    );
  }
}
