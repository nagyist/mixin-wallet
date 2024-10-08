import 'package:flutter/material.dart';

import '../../util/extension/extension.dart';
import '../../util/r.dart';
import '../router/mixin_routes.dart';
import 'action_button.dart';

class MixinBackButton extends StatelessWidget {
  const MixinBackButton({
    super.key,
    this.color,
    this.onTap,
  });

  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: ActionButton(
          name: R.resourcesIcBackSvg,
          color: color ?? BrightnessData.themeOf(context).icon,
          padding: const EdgeInsets.all(6),
          size: 24,
          onTap: () {
            if (onTap != null) return onTap?.call();
            context.pop();
          },
        ),
      );
}

class MixinBackButton2 extends StatelessWidget {
  const MixinBackButton2({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: ActionButton(
          name: R.resourcesBackBlackSvg,
          color: context.colorScheme.primaryText,
          padding: const EdgeInsets.all(6),
          size: 24,
          onTap: () {
            if (onTap != null) return onTap?.call();
            if (!context.canPop()) {
              context.replace(homeUri);
              return;
            }
            context.pop();
          },
        ),
      );
}

class HeaderButtonBarLayout extends StatelessWidget {
  const HeaderButtonBarLayout({
    required this.buttons,
    super.key,
  });

  final List<HeaderButton> buttons;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Material(
          color: context.colorScheme.surface,
          child: SizedBox(
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ...buttons
                    .map<Widget>((e) => Expanded(child: e))
                    .separated(_divider(context))
              ],
            ),
          ),
        ),
      );

  Widget _divider(BuildContext context) => Container(
        width: 2,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          color: context.colorScheme.background,
        ),
      );
}

class HeaderButton extends StatelessWidget {
  const HeaderButton({
    required this.child,
    required this.onTap,
    super.key,
  });

  factory HeaderButton.text({
    required String text,
    required VoidCallback onTap,
  }) =>
      HeaderButton(
        onTap: onTap,
        child: SelectableText(
          text,
          onTap: onTap,
          enableInteractiveSelection: false,
        ),
      );

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Center(
          child: DefaultTextStyle.merge(
            style: TextStyle(
              color: context.colorScheme.primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            child: child,
          ),
        ),
      );
}

class SendButton extends StatelessWidget {
  const SendButton({
    required this.onTap,
    required this.enable,
    super.key,
  });

  final VoidCallback onTap;
  final bool enable;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateColor.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return context.colorScheme.primaryText.withOpacity(0.2);
            }
            return context.colorScheme.primaryText;
          }),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          )),
          minimumSize: WidgetStateProperty.all(const Size(110, 48)),
          foregroundColor:
              WidgetStateProperty.all(context.colorScheme.background),
          shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(50))),
        ),
        onPressed: enable ? onTap : null,
        child: SelectableText(
          context.l10n.send,
          style: TextStyle(
            fontSize: 16,
            color: context.colorScheme.background,
          ),
          onTap: enable ? onTap : null,
          enableInteractiveSelection: false,
        ),
      );
}

class MixinPrimaryTextButton extends StatelessWidget {
  const MixinPrimaryTextButton({
    required this.onTap,
    required this.text,
    super.key,
    this.enable = true,
  });

  final VoidCallback onTap;
  final String text;
  final bool enable;

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: enable ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colorScheme.primaryText,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 24,
          ),
          minimumSize: const Size(110, 48),
          foregroundColor: context.colorScheme.background,
          shape: const StadiumBorder(),
        ),
        child: SelectableText(
          text,
          onTap: enable ? onTap : null,
          enableInteractiveSelection: false,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}
