import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../models/category.dart';
import '../../models/product.dart';
import '../demo/demo_mode.dart';
import '../network/api_config.dart';

enum ContentSource { server, assets }

/// Контент приложения: каталог, отели, суммы доставки, бренд, баннеры, контакты.
///
/// Источник правды — админка: `GET /app/config` отдаёт всё одним ответом, и
/// владелица меняет цены, фото, отели и тексты без выпуска новой версии.
/// Файлы `assets/content/*.json` — запасной контент для демо без сервера.
///
/// Загружается один раз в `main()` до `runApp`, дальше — [AppContent.instance].
class AppContent {
  const AppContent({
    required this.brand,
    required this.delivery,
    required this.payment,
    required this.warehouse,
    required this.contacts,
    required this.hotels,
    required this.categories,
    required this.products,
    required this.promoCodes,
    required this.banners,
  });

  final Brand brand;
  final DeliverySettings delivery;
  final PaymentSettings payment;
  final GeoPoint warehouse;
  final Contacts contacts;
  final List<Hotel> hotels;
  final List<Category> categories;
  final List<Product> products;
  final List<PromoCode> promoCodes;
  final List<PromoBanner> banners;

  static AppContent? _instance;

  static AppContent get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AppContent.load() не вызван до runApp');
    }
    return value;
  }

  /// Загружает контент до первого кадра.
  ///
  /// Источник — админка (`GET /app/config`), если [kContentFromApi]. Сервер
  /// недоступен: демо берёт ассеты, боевая сборка возвращает `false`, и
  /// `main()` показывает экран «Нет связи · Повторить» — показывать гостю
  /// вымышленный каталог из ассетов в настоящем магазине нельзя.
  static Future<bool> load({http.Client? client}) async {
    if (kContentFromApi) {
      final remote = await _fetchRemote(client ?? http.Client());
      if (remote != null) {
        _instance = _fromMaps(
          settings: remote,
          hotels: remote['hotels'] as List? ?? const [],
          categories: remote['categories'] as List? ?? const [],
          products: remote['products'] as List? ?? const [],
        );
        source = ContentSource.server;
        return true;
      }
      if (!kDemoMode) return false;
    }
    await _loadAssets();
    source = ContentSource.assets;
    return true;
  }

  /// Откуда пришёл текущий контент — для подписи в профиле и для тестов.
  static ContentSource source = ContentSource.assets;

  static Future<Map<String, dynamic>?> _fetchRemote(http.Client client) async {
    try {
      final response = await client
          .get(Uri.parse('${ApiConfig.baseUrl}/app/config'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> ? body : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _loadAssets() async {
    final settings = jsonDecode(
      await rootBundle.loadString('assets/content/settings.json'),
    ) as Map<String, dynamic>;
    final hotels = jsonDecode(
      await rootBundle.loadString('assets/content/hotels.json'),
    ) as Map<String, dynamic>;
    final catalog = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    ) as Map<String, dynamic>;
    _instance = _fromMaps(
      settings: settings,
      hotels: hotels['hotels'] as List? ?? const [],
      categories: catalog['categories'] as List? ?? const [],
      products: catalog['products'] as List? ?? const [],
    );
  }

  /// Для тестов: подставить контент без файлов и сети.
  static void setForTesting(AppContent content) => _instance = content;

  static AppContent _fromMaps({
    required Map<String, dynamic> settings,
    required List hotels,
    required List categories,
    required List products,
  }) {
    return AppContent(
      brand: Brand.fromJson(settings['brand'] as Map<String, dynamic>? ?? {}),
      delivery: DeliverySettings.fromJson(
        settings['delivery'] as Map<String, dynamic>? ?? {},
      ),
      payment: PaymentSettings.fromJson(
        settings['payment'] as Map<String, dynamic>? ?? {},
      ),
      warehouse: GeoPoint.fromJson(
        settings['warehouse'] as Map<String, dynamic>? ?? {},
      ),
      contacts: Contacts.fromJson(
        settings['contacts'] as Map<String, dynamic>? ?? {},
      ),
      hotels: [
        for (final h in hotels) Hotel.fromJson(h as Map<String, dynamic>),
      ].where((h) => h.active && h.name.isNotEmpty).toList(),
      categories: [
        for (final c in categories) _categoryFromJson(c as Map<String, dynamic>),
      ],
      products: [
        for (final p in products) _productFromJson(p as Map<String, dynamic>),
      ],
      promoCodes: [
        for (final p in (settings['promoCodes'] as List? ?? []))
          PromoCode.fromJson(p as Map<String, dynamic>),
      ],
      banners: [
        for (final b in (settings['banners'] as List? ?? []))
          PromoBanner.fromJson(b as Map<String, dynamic>),
      ].where((b) => b.title.isNotEmpty).toList(),
    );
  }

  Hotel? hotelByName(String name) {
    for (final hotel in hotels) {
      if (hotel.name == name) return hotel;
    }
    return null;
  }

  PromoCode? promoByCode(String code) {
    final needle = code.trim().toUpperCase();
    for (final promo in promoCodes) {
      if (promo.code == needle) return promo;
    }
    return null;
  }

  /// Иконки категорий: в JSON лежит короткое имя, чтобы заказчице не пришлось
  /// разбираться с названиями иконок Material.
  static const Map<String, IconData> _icons = {
    'gift': Icons.card_giftcard_outlined,
    'spa': Icons.spa_outlined,
    'basket': Icons.shopping_basket_outlined,
    'cafe': Icons.local_cafe_outlined,
    'cake': Icons.cake_outlined,
    'beach': Icons.beach_access_outlined,
    'drink': Icons.local_drink_outlined,
    'health': Icons.medical_services_outlined,
    'baby': Icons.child_friendly_outlined,
    'home': Icons.home_outlined,
  };

  static Category _categoryFromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        icon: _icons[json['icon'] as String? ?? ''] ??
            Icons.shopping_basket_outlined,
      );

  static Product _productFromJson(Map<String, dynamic> json) {
    final sku = json['sku'] as String? ?? 'p${json['id']}';
    // С сервера приходит полный адрес фото; в ассетах — имя файла по артикулу.
    final remote = json['photoUrl'] as String? ?? '';
    final photo = json['photo'] as String? ?? '$sku.jpg';
    return Product(
      id: json['id'] as int,
      categoryId: json['categoryId'] as int?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num? ?? 0).toDouble(),
      oldPrice: (json['oldPrice'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? '',
      imageAsset: json.containsKey('photoUrl') ? remote : 'assets/content/photos/$photo',
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }
}

class Brand {
  const Brand({
    required this.name,
    required this.tagline,
    required this.deliveryPromise,
    required this.logoFile,
    this.accentColor,
  });

  final String name;
  final String tagline;
  final String deliveryPromise;

  /// Адрес логотипа с сервера или путь в ассетах. Пусто — рисуется знак «TT».
  final String logoFile;

  /// Фирменный цвет из админки; null — цвет темы приложения.
  final Color? accentColor;

  bool get hasLogo => logoFile.isNotEmpty;

  /// «TT» из «TUR TUK»: первые буквы первых двух слов названия.
  String get monogram {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'TT';
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(1, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  factory Brand.fromJson(Map<String, dynamic> json) {
    final logoUrl = json['logoUrl'] as String? ?? '';
    final logoFile = json['logoFile'] as String? ?? '';
    return Brand(
      name: (json['name'] as String?)?.trim().isNotEmpty == true ? json['name'] as String : 'TUR TUK',
      tagline: json['tagline'] as String? ?? '',
      deliveryPromise: json['deliveryPromise'] as String? ?? '',
      logoFile: logoUrl.isNotEmpty
          ? logoUrl
          : (logoFile.isNotEmpty ? 'assets/content/photos/$logoFile' : ''),
      accentColor: _parseColor(json['accentColor'] as String?),
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return null;
    final value = int.tryParse(clean, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }
}

class DeliverySettings {
  const DeliverySettings({
    required this.minOrderTotal,
    required this.deliveryFee,
    required this.freeDeliveryFrom,
    required this.etaMinutes,
  });

  final double minOrderTotal;
  final double deliveryFee;
  final double freeDeliveryFrom;
  final int etaMinutes;

  /// Та же формула, что у сервера (`delivery_fee_for`): порог 0 — бесплатной
  /// доставки нет вовсе.
  double feeFor(double subtotal) =>
      freeDeliveryFrom > 0 && subtotal >= freeDeliveryFrom ? 0 : deliveryFee;

  factory DeliverySettings.fromJson(Map<String, dynamic> json) =>
      DeliverySettings(
        minOrderTotal: (json['minOrderTotal'] as num? ?? 3000).toDouble(),
        deliveryFee: (json['deliveryFee'] as num? ?? 300).toDouble(),
        freeDeliveryFrom: (json['freeDeliveryFrom'] as num? ?? 5000).toDouble(),
        etaMinutes: (json['etaMinutes'] as num? ?? 60).toInt(),
      );
}

class PaymentSettings {
  const PaymentSettings({
    required this.cardEnabled,
    required this.sbpEnabled,
    required this.cashEnabled,
  });

  final bool cardEnabled;
  final bool sbpEnabled;
  final bool cashEnabled;

  factory PaymentSettings.fromJson(Map<String, dynamic> json) =>
      PaymentSettings(
        cardEnabled: json['cardEnabled'] as bool? ?? true,
        sbpEnabled: json['sbpEnabled'] as bool? ?? true,
        cashEnabled: json['cashEnabled'] as bool? ?? false,
      );
}

class Contacts {
  const Contacts({
    required this.phone,
    required this.whatsapp,
    required this.telegram,
    required this.email,
    required this.supportHours,
    required this.privacyPolicyUrl,
    required this.supportUrl,
  });

  final String phone;
  final String whatsapp;
  final String telegram;
  final String email;
  final String supportHours;
  final String privacyPolicyUrl;
  final String supportUrl;

  factory Contacts.fromJson(Map<String, dynamic> json) => Contacts(
        phone: json['phone'] as String? ?? '',
        whatsapp: json['whatsapp'] as String? ?? '',
        telegram: json['telegram'] as String? ?? '',
        email: json['email'] as String? ?? '',
        supportHours: json['supportHours'] as String? ?? '',
        privacyPolicyUrl: json['privacyPolicyUrl'] as String? ?? '',
        supportUrl: json['supportUrl'] as String? ?? '',
      );
}

class Hotel {
  const Hotel({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.active,
  });

  final int id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final bool active;

  factory Hotel.fromJson(Map<String, dynamic> json) => Hotel(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        lat: (json['lat'] as num? ?? 0).toDouble(),
        lng: (json['lng'] as num? ?? 0).toDouble(),
        active: json['active'] as bool? ?? true,
      );
}

class GeoPoint {
  const GeoPoint({required this.name, required this.lat, required this.lng});

  final String name;
  final double lat;
  final double lng;

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num? ?? 0).toDouble(),
        lng: (json['lng'] as num? ?? 0).toDouble(),
      );
}

class PromoCode {
  const PromoCode({
    required this.code,
    required this.type,
    required this.value,
    required this.active,
    required this.title,
  });

  final String code;

  /// `percent` — процент от суммы, `fixed` — рубли.
  final String type;
  final double value;
  final bool active;
  final String title;

  double discountFor(double subtotal) {
    if (!active) return 0;
    final raw = type == 'percent' ? subtotal * value / 100 : value;
    return raw > subtotal ? subtotal : raw;
  }

  factory PromoCode.fromJson(Map<String, dynamic> json) => PromoCode(
        code: (json['code'] as String? ?? '').toUpperCase(),
        type: json['type'] as String? ?? 'percent',
        value: (json['value'] as num? ?? 0).toDouble(),
        active: json['active'] as bool? ?? true,
        title: json['title'] as String? ?? '',
      );
}

class PromoBanner {
  const PromoBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  factory PromoBanner.fromJson(Map<String, dynamic> json) => PromoBanner(
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
      );
}
