import '../core/demo/demo_state.dart';
import '../core/network/api_client.dart';
import '../models/category.dart';
import '../models/product.dart';

/// Задержка демо-ответов. Мгновенный ответ выглядит подозрительно ровно:
/// список появляется до того, как палец отпустил экран, и показ перестаёт
/// быть похожим на работу с сервером. 300 мс — достаточно, чтобы успел
/// мигнуть индикатор загрузки, и мало, чтобы это раздражало.
const Duration kDemoLatency = Duration(milliseconds: 300);

abstract class CatalogRepository {
  Future<List<Category>> categories();

  Future<List<Product>> products({int? categoryId, String? search});

  Future<Product> product(int id);
}

class DemoCatalogRepository implements CatalogRepository {
  const DemoCatalogRepository();

  @override
  Future<List<Category>> categories() async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.categoriesList;
  }

  @override
  Future<List<Product>> products({int? categoryId, String? search}) async {
    await Future<void>.delayed(kDemoLatency);
    final query = (search ?? '').trim().toLowerCase();
    return DemoState.instance.products.where((product) {
      if (categoryId != null && product.categoryId != categoryId) return false;
      if (query.isEmpty) return true;
      // Ищем и по описанию тоже — ровно как `list_products` на бэкенде
      // (`or_(Product.name.ilike, Product.description.ilike)`): «фисташ»
      // должно находить пахлаву, у которой фисташка только в описании.
      return product.name.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Future<Product> product(int id) async {
    await Future<void>.delayed(kDemoLatency);
    return DemoState.instance.product(id);
  }
}

class ApiCatalogRepository implements CatalogRepository {
  ApiCatalogRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<Category>> categories() async {
    final body = await _api.get('/catalog/categories', withAuth: false) as List;
    return [
      for (final item in body) Category.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<Product>> products({int? categoryId, String? search}) async {
    // Каталог маленький: пагинацию не показываем, но `limit` бэкенда
    // упирается в 100 — просить больше он всё равно не даст.
    final query = <String, dynamic>{'limit': 100};
    if (categoryId != null) query['category_id'] = categoryId;
    final trimmed = (search ?? '').trim();
    if (trimmed.isNotEmpty) query['search'] = trimmed;

    final body = await _api.get(
      '/catalog/products',
      query: query,
      withAuth: false,
    ) as Map<String, dynamic>;
    return [
      for (final item in (body['items'] as List))
        Product.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<Product> product(int id) async {
    final body =
        await _api.get('/catalog/products/$id', withAuth: false) as Map<String, dynamic>;
    return Product.fromJson(body);
  }
}
