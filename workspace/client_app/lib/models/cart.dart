import 'product.dart';

/// Позиция корзины. `id` — идентификатор ПОЗИЦИИ, а не товара: по нему
/// бэкенд правит количество (`PUT /cart/items/{item_id}`), и путать их
/// нельзя — у одного товара в разных корзинах разные `item_id`.
class CartItem {
  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
  });

  final int id;
  final Product product;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
        id: id,
        product: product,
        quantity: quantity ?? this.quantity,
      );

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'] as int,
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: json['quantity'] as int,
      );
}

class Cart {
  const Cart({this.items = const [], this.total = 0});

  final List<CartItem> items;
  final double total;

  /// Число ЕДИНИЦ товара, а не число позиций: бейдж на вкладке «Корзина»
  /// в «Самокате» показывает именно это, и «3» при трёх банках одного кофе
  /// понятнее, чем «1».
  int get count => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) => Cart(
        items: [
          for (final item in (json['items'] as List? ?? const []))
            CartItem.fromJson(item as Map<String, dynamic>),
        ],
        total: (json['total'] as num?)?.toDouble() ?? 0,
      );
}
