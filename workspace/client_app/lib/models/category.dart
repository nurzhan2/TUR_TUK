import 'package:flutter/material.dart';

/// Категория каталога.
///
/// `icon` бэкенд не отдаёт (`app/schemas/catalog.py::CategoryOut` — это
/// `id`, `name`, `children`), поэтому иконка подбирается на клиенте по
/// названию: [iconFor]. Пустую плитку без иконки в макете «Самоката» ничем
/// не заменить, а заводить ради неё колонку в БД — правка чужого бэкенда.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId,
    this.children = const [],
    this.icon = Icons.category_outlined,
  });

  final int id;
  final String name;
  final int? parentId;
  final List<Category> children;
  final IconData icon;

  factory Category.fromJson(Map<String, dynamic> json, {int? parentId}) {
    final id = json['id'] as int;
    final name = json['name'] as String;
    return Category(
      id: id,
      name: name,
      parentId: parentId,
      children: [
        for (final child in (json['children'] as List? ?? const []))
          Category.fromJson(child as Map<String, dynamic>, parentId: id),
      ],
      icon: iconFor(name),
    );
  }

  /// Сопоставление названия и иконки. Поиск по вхождению подстроки, а не по
  /// точному равенству: категория может называться «Косметика и уход».
  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    for (final entry in _byKeyword.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return Icons.category_outlined;
  }

  static const Map<String, IconData> _byKeyword = {
    'сувенир': Icons.card_giftcard_outlined,
    'косметик': Icons.spa_outlined,
    'продукт': Icons.shopping_basket_outlined,
    'напит': Icons.local_cafe_outlined,
    'сладост': Icons.cake_outlined,
    'пляж': Icons.beach_access_outlined,
  };
}
