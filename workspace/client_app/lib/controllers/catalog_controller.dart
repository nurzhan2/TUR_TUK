// `hide Category`: во `flutter/foundation` есть своя аннотация с таким
// именем, и без этого `Category` из моделей становится неоднозначным.
import 'package:flutter/foundation.dart' hide Category;

import '../core/di.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'controller_state.dart';

/// Каталог: категории, товары, выбранная категория и строка поиска.
class CatalogController extends ChangeNotifier {
  ControllerState state = ControllerState.initial;
  String? errorMessage;

  List<Category> categories = const [];
  List<Product> products = const [];
  int? selectedCategoryId;
  String searchQuery = '';

  /// Счётчик запросов: ответ на УСТАРЕВШИЙ запрос выбрасывается.
  ///
  /// Без него поиск показывает не то, что набрано: человек печатает
  /// «лукум», три запроса уходят подряд, а придут они в любом порядке —
  /// и на экране останется результат по «лук».
  int _requestId = 0;

  Future<void> load() async {
    state = ControllerState.loading;
    errorMessage = null;
    notifyListeners();

    final requestId = ++_requestId;
    try {
      final results = await Future.wait([
        Di.catalog.categories(),
        Di.catalog.products(
          categoryId: selectedCategoryId,
          search: searchQuery.isEmpty ? null : searchQuery,
        ),
      ]);
      if (requestId != _requestId) return;
      categories = results[0] as List<Category>;
      products = results[1] as List<Product>;
      state = ControllerState.loaded;
    } catch (error) {
      if (requestId != _requestId) return;
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  Future<void> selectCategory(int? categoryId) async {
    selectedCategoryId = categoryId;
    notifyListeners();
    await _reloadProducts();
  }

  Future<void> search(String query) async {
    searchQuery = query.trim();
    notifyListeners();
    await _reloadProducts();
  }

  /// Перезагружаются только ТОВАРЫ: категории от смены фильтра не меняются,
  /// а их мигание при каждом нажатии на чип выглядит как перерисовка всего
  /// экрана.
  Future<void> _reloadProducts() async {
    final requestId = ++_requestId;
    try {
      final loaded = await Di.catalog.products(
        categoryId: selectedCategoryId,
        search: searchQuery.isEmpty ? null : searchQuery,
      );
      if (requestId != _requestId) return;
      products = loaded;
      state = ControllerState.loaded;
      errorMessage = null;
    } catch (error) {
      if (requestId != _requestId) return;
      state = ControllerState.error;
      errorMessage = '$error';
    }
    notifyListeners();
  }

  /// Товар по id из уже загруженного списка — чтобы карточка открывалась
  /// без второго запроса, если пользователь пришёл из каталога.
  Product? cached(int id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }
}
