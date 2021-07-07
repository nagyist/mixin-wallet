import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

const _bound = {
  Brightness.light: 0.0,
  Brightness.dark: 1.0,
};

class BrightnessObserver extends HookWidget {
  const BrightnessObserver({
    Key? key,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.linear,
    required this.child,
    required this.lightThemeData,
    this.darkThemeData,
    this.forceBrightness,
  }) : super(key: key);

  final Duration duration;
  final Curve curve;
  final Widget child;
  final BrightnessThemeData lightThemeData;
  final BrightnessThemeData? darkThemeData;
  final Brightness? forceBrightness;

  @override
  Widget build(BuildContext context) {
    final brightness =
        forceBrightness ?? MediaQuery.platformBrightnessOf(context);

    final animationController = useAnimationController(
      duration: duration,
      initialValue: _bound[brightness]!,
    );

    final progress = useAnimation(
        CurvedAnimation(parent: animationController, curve: curve));

    useValueChanged<Brightness, void>(brightness, (_, __) {
      if (brightness == Brightness.light) {
        animationController.reverse();
      } else {
        animationController.forward();
      }
    });

    return BrightnessData(
      value: progress,
      brightnessThemeData: darkThemeData != null
          ? BrightnessThemeData.lerp(lightThemeData, darkThemeData!, progress)
          : lightThemeData,
      child: child,
    );
  }
}

class BrightnessData extends InheritedWidget {
  const BrightnessData({
    required this.value,
    required Widget child,
    Key? key,
    required this.brightnessThemeData,
  }) : super(key: key, child: child);

  final double value;
  final BrightnessThemeData brightnessThemeData;

  @override
  bool updateShouldNotify(covariant BrightnessData oldWidget) =>
      value != oldWidget.value ||
      brightnessThemeData != oldWidget.brightnessThemeData;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BrightnessData>()!.value;

  static BrightnessThemeData themeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BrightnessData>()!
      .brightnessThemeData;

  static Color dynamicColor(
    BuildContext context,
    Color color, {
    Color? darkColor,
  }) {
    if (darkColor == null) return color;
    return Color.lerp(color, darkColor, of(context))!;
  }
}

class BrightnessThemeData extends Equatable {
  const BrightnessThemeData({
    required this.accent,
    required this.text,
    required this.icon,
    required this.secondaryText,
    required this.red,
    required this.green,
    required this.warning,
    required this.background,
  });

  final Color accent;
  final Color text;
  final Color icon;
  final Color secondaryText;
  final Color red;
  final Color green;
  final Color warning;
  final Color background;

  static BrightnessThemeData lerp(
          BrightnessThemeData begin, BrightnessThemeData end, double t) =>
      BrightnessThemeData(
        accent: Color.lerp(begin.accent, end.accent, t)!,
        text: Color.lerp(begin.text, end.text, t)!,
        icon: Color.lerp(begin.icon, end.icon, t)!,
        secondaryText: Color.lerp(begin.secondaryText, end.secondaryText, t)!,
        red: Color.lerp(begin.red, end.red, t)!,
        green: Color.lerp(begin.green, end.green, t)!,
        warning: Color.lerp(begin.warning, end.warning, t)!,
        background: Color.lerp(begin.background, end.background, t)!,
      );

  @override
  List<Object?> get props => [
        accent,
        text,
        secondaryText,
        red,
        green,
        warning,
        background,
      ];
}

extension Theme on BuildContext {
  BrightnessThemeData get theme => BrightnessData.themeOf(this);
}