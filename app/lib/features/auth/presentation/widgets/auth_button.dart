import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/salone_buttons.dart';

enum AuthButtonVariant {
  primary,
  secondary,
}

/// Primary and secondary action buttons conforming to SaloneMarket design language.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = AuthButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final AuthButtonVariant variant;
  final bool isLoading;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final IconData? iconData = icon is Icon ? (icon! as Icon).icon : null;
    if (variant == AuthButtonVariant.primary) {
      return SalonePrimaryButton(
        label: text,
        onPressed: onPressed,
        isLoading: isLoading,
        icon: iconData,
        height: 52,
      );
    }
    return SaloneSecondaryButton(
      label: text,
      onPressed: isLoading ? null : onPressed,
      icon: iconData,
      borderColor: SaloneColors.primary,
      height: 52,
    );
  }
}
