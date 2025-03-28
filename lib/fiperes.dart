library fiperes;

import 'dart:convert';
import 'package:flutter/foundation.dart';

class ProviderCore<T>{
  T Function(ProviderRef<T>) createFn;
  T value;

  ProviderCore({
    required this.createFn,
    required this.value,
  });
}

class ProviderRef<T>{
  final ProviderObserver _observer = ProviderObserver();

  final Provider<T> provider;

  ProviderRef({
    required this.provider
  });

  T read(Provider<T> otherProvider){
    return otherProvider.read();
  }

  void update(T Function(T) updateFn){
    final oldValue = provider.read();
    provider.update(updateFn);
    final newValue = provider.read();

    _observer.logUpdate(provider, oldValue, newValue);
  }

  void watch(Provider<T> otherProvider, T Function(T) updateFn){
    _observer.addDependency(provider, otherProvider);
    provider._addDependency(
      otherProvider, 
      Dependency(
        parentProvider: otherProvider,
        provider: provider,
        updateFn: updateFn
      )
    );
  }
}

class Dependency<T>{
  final Provider<T> parentProvider;
  final Provider<T> provider;

  late final Function() _unsubscribed;

  Dependency({
    required this.parentProvider,
    required this.provider,
    required T Function(T) updateFn
  }){
    _listenParent(updateFn);
  }

  void _listenParent(T Function(T) updateFn){
    _unsubscribed = parentProvider.watch(
      (T parentValue) {
        provider.update((_) {
          return updateFn(parentValue);
        });
      }
    );
  }

  void unsubscribedParent(){
    _unsubscribed();
  }
}

class Provider<T>{
  final Map<Provider<T>, Dependency<T>> _dependencies = {};
  final Set _listeners = {};
  late final ProviderCore<T> _core; 
  late final String _name;

  Provider._(T Function(ProviderRef<T>) createFn){
    final ProviderRef<T> ref = _createRef();

    _core = ProviderCore(
      createFn: createFn,
      value: createFn(ref)
    );
  }

  static Provider<T> createProvider<T>(T Function(ProviderRef<T>) createFn, String name){
    final Provider<T> provider = Provider<T>._(createFn);
    provider._setName(name);

    return provider;
  }

  void _setName(String name){
    _name = name;
  }

  T read(){
    return _core.value;
  }

  Function() watch(Function(T) listener, { bool immediate = true }){
    _listeners.add(listener);

    if(immediate) listener(read());

    return () {
      _listeners.remove(listener);
    };
  }

  void update(T Function(T) updateFn){
    final T currentValue = read();
    final T newValue = updateFn(currentValue);

    final ProviderObserver observer = ProviderObserver();
    observer.logUpdate(this, currentValue, newValue);

    _core.value = newValue;
    _notifyListeners(newValue);
  }

  void _notifyListeners(T newValue){
    _listeners.forEach((listener) => listener(newValue));
  }

  ProviderRef<T> _createRef(){
    return ProviderRef<T>(provider: this);
  }

  void _addDependency(Provider<T> otherProvider, Dependency<T> dependency) {
    _dependencies[otherProvider] = dependency;
  }

  void unsubscribedDependency(Provider<T> parentProvider){
    final ProviderObserver observer = ProviderObserver();

    _dependencies[parentProvider]?.unsubscribedParent();
    _dependencies.remove(parentProvider);

    observer.deleteDependency(this, parentProvider);
  }
}

class ProviderObserver {
  static ProviderObserver? _instance;
  factory ProviderObserver() {
    _instance ??= ProviderObserver._();
    return _instance!;
  }

  ProviderObserver._();

  final Map<Provider<dynamic>, Set<Provider<dynamic>>> dependencyGraph = {};
  final List<Map<String, dynamic>> updateHistory = [];
  bool _isOutedLog = true;

  void outLogs(bool isOutedLog) {
    _isOutedLog = isOutedLog;
  }

  void addDependency(Provider<dynamic> childProvider, Provider<dynamic> parentProvider) {
    if (!dependencyGraph.containsKey(childProvider)) {
      dependencyGraph[childProvider] = <Provider<dynamic>>{};
    }
    dependencyGraph[childProvider]!.add(parentProvider);
    log('Dependency added: ${_getProviderInfo(childProvider)} depends on ${_getProviderInfo(parentProvider)}');
  }

  void deleteDependency(Provider<dynamic> childProvider, Provider<dynamic> parentProvider) {
    if (dependencyGraph.containsKey(childProvider)) {
      dependencyGraph[childProvider]!.remove(parentProvider);
    }
    log('Dependency deleted: ${_getProviderInfo(childProvider)} unsubscribed ${_getProviderInfo(parentProvider)}');
  }

  bool _isLargeObject(dynamic obj, {int maxSize = 1024 * 10}) {
    try {
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(obj)));
      return bytes.length > maxSize;
    } catch (e) {
      debugPrint('オブジェクトの解析中にエラーが発生しました: $e');
      return true;
    }
  }

  void logUpdate(Provider<dynamic> provider, dynamic oldValue, dynamic newValue) {
    String? formatValue(dynamic value) {
      if (value == null) return null;
      return value.toString();
    }

    oldValue = formatValue(oldValue);
    newValue = formatValue(newValue);

    if (_isLargeObject(oldValue)) {
      oldValue = 'Large Object (simplified)';
    }

    if (_isLargeObject(newValue)) {
      newValue = 'Large Object (simplified)';
    }

    final record = {
      'timestamp': DateTime.now(),
      'provider': provider._name,
      'oldValue': oldValue,
      'newValue': newValue,
      'stackTrace': _getStackTrace()
    };

    updateHistory.add(record);

    log('Update: ${record['provider']} changed from ${jsonEncode(oldValue)} to ${jsonEncode(newValue)}');
  }

  Map<String, List<String>> getDependencyGraph() {
    final graph = <String, List<String>>{};
    dependencyGraph.forEach((provider, dependencies) {
      graph[_getProviderInfo(provider)] = 
          dependencies.map((dep) => _getProviderInfo(dep)).toList();
    });
    return graph;
  }

  List<Map<String, dynamic>> getAllUpdateHistory() => updateHistory;

  List<Map<String, dynamic>> getFilteredUpdateHistory(Provider<dynamic> provider) {
    return updateHistory.where((history) =>
        history['provider'] == _getProviderInfo(provider)
    ).toList();
  }

  String _getProviderInfo(Provider<dynamic> provider) => provider._name;

  String _getStackTrace() {
    final error = Error();
    final String stackTrace = error.stackTrace.toString();
    return stackTrace;
  }

  void log(String message, [dynamic obj]) {
    if (!_isOutedLog) return;
    
    final baseMessage = '[ProviderObserver] $message';
    
    if (obj != null) {
      debugPrint('$baseMessage ${jsonEncode(obj)}');
    } else {
      debugPrint(baseMessage);
    }
  }

  static void clearInstance() {
    _instance = null;
  }
}
