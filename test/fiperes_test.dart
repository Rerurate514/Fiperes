import 'package:flutter_test/flutter_test.dart';

import 'package:fiperes/fiperes.dart';

void main() {
  group('ProviderCore テスト', () {
    test('初期値が正しく設定される', () {
      final createFn = (ref) => 42;
      final initialValue = 42;
      
      final providerCore = ProviderCore<int>(
        createFn: createFn,
        value: initialValue,
      );

      expect(providerCore.value, initialValue);
      expect(createFn(null), 42);
    });
  });

  group('ProviderRef テスト', () {
    late Provider<int> mockProvider;
    
    setUp(() {
      mockProvider = Provider.createProvider<int>((ref) => 0, 'mock_provider');
    });

    test('read が正しく動作する', () {
      final ref = ProviderRef<int>(provider: mockProvider);
      final result = ref.read(mockProvider);
      expect(result, 0);
    });

    test('update が正しく動作する', () {
      final ref = ProviderRef<int>(provider: mockProvider);
      ref.update((value) => value + 1);
      expect(mockProvider.read(), 1);
    });

    test('watch が正しく依存関係を設定する', () {
      final ref = ProviderRef<int>(provider: mockProvider);
      final dependentProvider = Provider.createProvider<int>((ref) => 100, 'dependent');

      ref.watch(dependentProvider, (value) => value * 2);
      
      dependentProvider.update((value) => value + 1);
      expect(mockProvider.read(), 202);
    });
  });

  group('Dependency テスト', () {
    late Provider<int> parentProvider;
    late Provider<int> childProvider;

    setUp(() {
      parentProvider = Provider.createProvider<int>((ref) => 0, 'parent');
      childProvider = Provider.createProvider<int>((ref) => 0, 'child');
    });

    test('依存関係が正しく設定される', () {
      final dependency = Dependency<int>(
        parentProvider: parentProvider,
        provider: childProvider,
        updateFn: (value) => value * 2,
      );

      parentProvider.update((value) => 10);
      expect(childProvider.read(), 20);
    });

    test('unsubscribedParent が正しく動作する', () {
      final dependency = Dependency<int>(
        parentProvider: parentProvider,
        provider: childProvider,
        updateFn: (value) => value * 2,
      );

      dependency.unsubscribedParent();
      
      parentProvider.update((value) => 20);
      expect(childProvider.read(), 0); // 更新されていないことを確認
    });
  });

  group('Provider テスト', () {
    late Provider<int> provider;

    setUp(() {
      provider = Provider.createProvider<int>((ref) => 0, 'test_provider');
    });

    test('read が正しく動作する', () {
      expect(provider.read(), 0);
    });

    test('watch がリスナーを正しく管理する', () {
      bool listenerCalled = false;
      final unsubscribe = provider.watch((value) {
        listenerCalled = true;
      }, immediate: false);

      provider.update((value) => 42);
      expect(listenerCalled, true);
      expect(provider.read(), 42);

      unsubscribe();
      provider.update((value) => 84);
      expect(listenerCalled, true); // リスナーが削除されているため、更新されない
    });

    test('_notifyListeners が正しく動作する', () {
      List<int> values = [];
      provider.watch((value) => values.add(value));
      
      provider.update((value) => 10);
      expect(values, [0, 10]);
      
      provider.update((value) => 20);
      expect(values, [0, 10, 20]);
    });
  });
}
