/// Состояние экрана: четыре значения на всех контроллеров.
///
/// Один enum, а не свой у каждого контроллера: экраны различают эти
/// состояния одинаково (спиннер / список / ошибка с «повторить»), и пять
/// одинаковых перечислений разошлись бы на первой же правке.
enum ControllerState { initial, loading, loaded, error }

extension ControllerStateX on ControllerState {
  bool get isLoading => this == ControllerState.loading;

  bool get isError => this == ControllerState.error;

  bool get isLoaded => this == ControllerState.loaded;
}
