library fiperes;

class ProviderCore<T>{
  T Function(ProviderRef<T>) createFn;
  T value;

  ProviderCore({
    required this.createFn,
    required this.value,
  });
}

class ProviderRef<T>{
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


  }

  void watch(Provider<T> otherProvider, T Function(T) updateFn){
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

    if(immediate){
      listener(read());
    }

    return () {
      _listeners.remove(listener);
    };
  }

  void update(T Function(T) updateFn){
    final T currentValue = read();
    final T newValue = updateFn(currentValue);

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
    _dependencies[parentProvider]?.unsubscribedParent();
    _dependencies.remove(parentProvider);
  }
}
