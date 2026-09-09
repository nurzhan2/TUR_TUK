/// Товар каталога.
///
/// `imageAsset` — путь к КАРТИНКЕ В АССЕТАХ, а не URL: демо работает без сети
/// и без бэкенда, `Image.asset` в нём единственный способ показать фото.
/// В боевом режиме сюда маппится `photo_url` из `ProductOut`, и экран,
/// увидев `http`-путь, показывает его через `Image.network` — решение
/// принимает виджет, модель хранит строку как есть.
///
/// `unit` и `oldPrice` бэкенд не отдаёт (`app/schemas/product.py`): единица
/// измерения и «старая цена» для бейджа скидки живут пока только в демо.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    this.categoryId,
    this.imageAsset = '',
    this.unit = 'шт',
    this.isAvailable = true,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final int? categoryId;
  final String imageAsset;
  final String unit;
  final bool isAvailable;

  /// Есть ли скидка — старая цена не просто заполнена, а действительно выше.
  bool get hasDiscount => oldPrice != null && oldPrice! > price;

  /// Процент скидки для бейджа: «−25%».
  int get discountPercent =>
      hasDiscount ? (100 - price / oldPrice! * 100).round() : 0;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as int,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        price: (json['price'] as num).toDouble(),
        oldPrice: (json['old_price'] as num?)?.toDouble(),
        categoryId: json['category_id'] as int?,
        imageAsset: (json['photo_url'] as String?) ?? '',
        unit: (json['unit'] as String?) ?? 'шт',
        isAvailable: (json['is_available'] as bool?) ?? true,
      );

  Product copyWith({double? price, bool? isAvailable}) => Product(
        id: id,
        name: name,
        description: description,
        price: price ?? this.price,
        oldPrice: oldPrice,
        categoryId: categoryId,
        imageAsset: imageAsset,
        unit: unit,
        isAvailable: isAvailable ?? this.isAvailable,
      );
}
