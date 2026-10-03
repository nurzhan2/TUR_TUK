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

  /// Сервер кладёт рядом с каждым фото превью ~480 px: `x.webp` → `x.thumb.webp`.
  static const _thumbMaxPx = 520.0;

  static String? thumbFor(String source) {
    if (!source.endsWith('.webp') || source.endsWith('.thumb.webp')) return null;
    return '${source.substring(0, source.length - 5)}.thumb.webp';
  }

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
    // Карточка каталога ~160 pt: тянуть и декодировать оригинал 1600 px
    // ради неё — лишний трафик гостю в роуминге и заметные подвисания
    // в web-сборке. Под небольшое место берём превью, при ошибке — оригинал.
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final logical = constraints.hasBoundedWidth ? constraints.maxWidth : (width ?? double.infinity);
        final px = logical * dpr;
        final thumb = px.isFinite && px <= _thumbMaxPx ? thumbFor(source) : null;
        // cacheWidth автоматически не ставим: при BoxFit.cover горизонтальное
        // фото, ужатое по ширине, растянулось бы в квадрате и поплыло.
        final decodeWidth = cacheWidth;
        if (thumb == null) return _network(source, decodeWidth, errorBuilder);
        return _network(
          thumb,
          decodeWidth,
          (context, error, stack) => _network(source, decodeWidth, errorBuilder),
        );
      },
    );
  }

  Widget _network(String url, int? decodeWidth, ImageErrorWidgetBuilder? onError) {
    return Image.network(
      url,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      semanticLabel: semanticLabel,
      cacheWidth: decodeWidth,
      gaplessPlayback: true,
      errorBuilder: onError ?? (_, _, _) => const _Placeholder(),
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
