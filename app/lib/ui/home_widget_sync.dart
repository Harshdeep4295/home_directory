import 'dart:async';
import 'dart:io';

import 'package:home_widget/home_widget.dart';

import '../core/models.dart';

/// Home-screen widget + quick-settings tile glue (T5.9). The Android side lives in
/// OfflineHomeWidget.kt / VoiceTileService.kt; it reads the keys written here and opens
/// the app with an `offlinehome://` URI, which [parseWidgetUri] turns into an action.

/// `Device.meta` flag marking a device as a widget favourite.
const favouriteMetaKey = 'favourite';

/// Slots shown by the widget (res/layout/offline_home_widget.xml has fav0..fav3).
const widgetSlots = 4;

bool isFavourite(Device d) => d.meta[favouriteMetaKey] == true;

Device withFavourite(Device d, bool fav) {
  final meta = Map<String, Object?>.of(d.meta);
  if (fav) {
    meta[favouriteMetaKey] = true;
  } else {
    meta.remove(favouriteMetaKey);
  }
  return d.copyWith(meta: meta);
}

/// Up to [widgetSlots] favourites, by name.
List<Device> widgetFavourites(List<Device> devices) =>
    (devices.where(isFavourite).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        ))
        .take(widgetSlots)
        .toList();

/// Key/values the Kotlin provider reads: `fav{i}_id`, `fav{i}_name`, `fav{i}_on`.
/// Unused slots get an empty id so the widget hides them.
Map<String, Object> widgetData(
  List<Device> devices,
  Map<String, DeviceState> states,
) {
  final favs = widgetFavourites(devices);
  return {
    for (var i = 0; i < widgetSlots; i++) ...{
      'fav${i}_id': i < favs.length ? favs[i].id : '',
      'fav${i}_name': i < favs.length ? favs[i].name : '',
      'fav${i}_on': i < favs.length && states[favs[i].id]?.on == true,
    },
  };
}

/// What a widget / tile tap asks the app to do.
sealed class WidgetAction {
  const WidgetAction();
}

final class OpenVoice extends WidgetAction {
  const OpenVoice();
}

final class ToggleDevice extends WidgetAction {
  const ToggleDevice(this.deviceId);
  final String deviceId;
}

WidgetAction? parseWidgetUri(Uri? uri) {
  if (uri == null || uri.scheme != 'offlinehome') return null;
  return switch (uri.host) {
    'voice' => const OpenVoice(),
    'toggle' when uri.pathSegments.isNotEmpty => ToggleDevice(
      uri.pathSegments.first,
    ),
    _ => null,
  };
}

/// Platform seam so widget tests never touch the plugin.
abstract class HomeWidgetBridge {
  Future<void> publish(Map<String, Object> data);
  Future<Uri?> initialUri();
  Stream<Uri?> get clicks;

  factory HomeWidgetBridge.forPlatform() =>
      Platform.isAndroid ? PluginHomeWidgetBridge() : const NoHomeWidget();
}

class NoHomeWidget implements HomeWidgetBridge {
  const NoHomeWidget();
  @override
  Future<void> publish(Map<String, Object> data) async {}
  @override
  Future<Uri?> initialUri() async => null;
  @override
  Stream<Uri?> get clicks => const Stream.empty();
}

class PluginHomeWidgetBridge implements HomeWidgetBridge {
  static const androidProvider =
      'dev.offlinehome.offline_home.OfflineHomeWidget';

  @override
  Future<void> publish(Map<String, Object> data) async {
    try {
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<Object>(e.key, e.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } on Exception {
      // No widget placed / plugin unavailable: nothing to refresh.
    }
  }

  @override
  Future<Uri?> initialUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } on Exception {
      return null;
    }
  }

  @override
  Stream<Uri?> get clicks => HomeWidget.widgetClicked;
}
