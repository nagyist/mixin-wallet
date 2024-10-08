import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../util/logger.dart';
import '../../util/web/web_utils.dart';
import 'auth.dart';

Future<void> initStorage() async {
  Hive.registerAdapter(_AuthAdapter());
  await Hive.initFlutter();
  fixSafariIndexDb();
  await Hive.openBox<dynamic>('profile');
  await Hive.openBox<dynamic>('swap');
  await Hive.openBox<dynamic>('session');
}

Box<dynamic> get profileBox => Hive.box('profile');

List<String> get searchAssetHistory =>
    ((profileBox.get('searchAssetHistory') as List<dynamic>?) ?? [])
        .map((e) => e as String)
        .toList();

void putSearchAssetHistory(String assetId) {
  final list = searchAssetHistory;
  profileBox.put('searchAssetHistory', [
    assetId,
    if (list.isNotEmpty) list.first,
  ]);
}

List<String> get topAssetIds =>
    ((profileBox.get('topAssetIds') as List<dynamic>?) ?? [])
        .map((e) => e as String)
        .toList();

void replaceTopAssetIds(List<String> topAssetIds) =>
    profileBox.put('topAssetIds', topAssetIds);

bool get _isSmallAssetsHidden {
  final ret = profileBox.get('isSmallAssetsHidden');
  return (ret is bool ? ret : null) ?? false;
}

set _isSmallAssetsHidden(bool value) =>
    profileBox.put('isSmallAssetsHidden', value);

final ValueNotifier<bool> isSmallAssetsHidden = () {
  final notifier = ValueNotifier(_isSmallAssetsHidden);
  notifier.addListener(() {
    _isSmallAssetsHidden = notifier.value;
  });
  return notifier;
}();

String? get lastSelectedAddress =>
    profileBox.get('lastSelectedAddress') as String?;

set lastSelectedAddress(String? value) =>
    profileBox.put('lastSelectedAddress', value);

class _AuthAdapter extends TypeAdapter<Auth?> {
  @override
  Auth? read(BinaryReader reader) {
    final json = reader.readString();
    try {
      return Auth.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (error, stacktrace) {
      e('_AuthAdapter: read auth error: $error, $stacktrace');
      return null;
    }
  }

  @override
  int get typeId => 0;

  @override
  void write(BinaryWriter writer, Auth? obj) {
    if (obj == null) {
      writer.writeString('');
    } else {
      writer.writeString(jsonEncode(obj));
    }
  }
}
