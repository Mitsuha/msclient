import 'package:flutter/cupertino.dart';

/// The MirrorStages palette: every color used in the app, named by role.
///
/// One value, one token — reuse the closest existing role instead of adding a
/// near-duplicate shade, and add a new token here rather than inlining a
/// `Color(0x...)` literal in a widget.
abstract final class AppColors {
  // Apple system accents.
  static const Color blue = Color(0xFF007AFF);
  static const Color green = Color(0xFF34C759);
  static const Color orange = Color(0xFFFF9500);
  static const Color red = Color(0xFFFF3B30);

  // Text and icons.
  static const Color label = Color(0xFF1D1D1F);
  static const Color secondaryLabel = Color(0xFF6E6E73);
  static const Color tertiaryLabel = Color(0xFF8E8E93);
  static const Color placeholderText = Color(0xFFB0B0B5);
  static const Color icon = Color(0xFF3A3A3C);

  // Neutral surfaces and borders, light → dark.
  static const Color sectionBackground = Color(0xFFFBFBFD);
  static const Color optionBackground = Color(0xFFF7F7F9);
  static const Color windowBackground = Color(0xFFF5F5F7);
  static const Color sidebarBackground = Color(0xFFF4F4F6);
  static const Color hoverBackground = Color(0xFFF2F2F7);
  static const Color mutedBackground = Color(0xFFEFEFF4);
  static const Color divider = Color(0xFFECECEF);
  static const Color secondaryButtonBackground = Color(0xFFEAEAEC);
  static const Color neutralButtonBackground = Color(0xFFE9E9ED);
  static const Color border = Color(0xFFE5E5EA);
  static const Color menuHoverBackground = Color(0xFFE1E1E5);
  static const Color strongBorder = Color(0xFFD7D7DB);
  static const Color disabledButtonBackground = Color(0xFFC7C7CC);

  // Status tints: text / background / border families per tone.
  static const Color successText = Color(0xFF248A3D);
  static const Color successBackground = Color(0xFFE3F7EA);
  static const Color greenTintBackground = Color(0xFFF1FAF3);
  static const Color greenTintBorder = Color(0xFFCFEED5);
  static const Color infoTintBackground = Color(0xFFF1F7FF);
  static const Color infoTintBorder = Color(0xFFCFE3FF);
  static const Color blueChipBackground = Color(0xFFE8F2FF);
  static const Color selectedOptionBackground = Color(0xFFF0F6FF);
  static const Color dangerText = Color(0xFFC93400);
  static const Color dangerBackground = Color(0xFFFDE7E1);
  static const Color errorText = Color(0xFFC7362C);
  static const Color redTintBackground = Color(0xFFFFF4F3);
  static const Color redTintBorder = Color(0xFFFFD2CC);
  static const Color redDisabled = Color(0xFFFFC3BF);
  static const Color redDisabledBright = Color(0xFFFFB3AD);
  static const Color orangeDisabled = Color(0xFFFFD59A);
  static const Color orangeTintBackground = Color(0xFFFFF8E8);
  static const Color orangeTintBorder = Color(0xFFFFE1A8);

  // Brand badges.
  static const Color claudeBrand = Color(0xFFD97757);
  static const Color planBadgeText = Color(0xFF3B5BDB);
  static const Color planBadgeBackground = Color(0xFFE8EBFF);

  // Overlays and shadows.
  static const Color transparent = Color(0x00000000);
  static const Color cardShadow = Color(0x0F000000);
  static const Color menuShadow = Color(0x24000000);
  static const Color overlayCardShadow = Color(0x26000000);
  static const Color barrier = Color(0x33000000);
  static const Color loginBarrier = Color(0x66F5F5F7);
}
