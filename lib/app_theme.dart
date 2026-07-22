import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const primary = Color(0xFF007AFF);
  const error = Color(0xFFFF3B30);
  const background = Color(0xFFF2F2F7);
  const surface = Color(0xFFFFFFFF);
  const elevatedSurface = Color(0xFFFFFFFF);
  const fieldFill = Color(0xFFF2F2F7);
  const primaryLabel = Color(0xFF1C1C1E);
  const secondaryLabel = Color(0xFF636366);
  const separator = Color(0xFFC6C6C8);

  final scheme =
      ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
      ).copyWith(
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primary.withValues(alpha: .12),
        onPrimaryContainer: primary,
        secondary: const Color(0xFF5856D6),
        tertiary: const Color(0xFF248A3D),
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: primaryLabel,
        onSurfaceVariant: secondaryLabel,
        surfaceContainerLowest: background,
        surfaceContainerLow: surface,
        surfaceContainer: surface,
        surfaceContainerHigh: elevatedSurface,
        surfaceContainerHighest: fieldFill,
        outline: separator,
        outlineVariant: separator.withValues(alpha: .55),
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: NoSplash.splashFactory,
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: const BorderRadius.all(Radius.circular(8)),
    borderSide: BorderSide(color: scheme.outlineVariant),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: primaryLabel,
      displayColor: primaryLabel,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      bodyColor: primaryLabel,
      displayColor: primaryLabel,
    ),
    dividerColor: separator.withValues(alpha: .7),
    dividerTheme: DividerThemeData(
      color: separator.withValues(alpha: .7),
      thickness: .5,
      space: 1,
    ),
    appBarTheme: AppBarTheme(
      toolbarHeight: 44,
      backgroundColor: surface.withValues(alpha: .94),
      foregroundColor: primaryLabel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        color: primaryLabel,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: primary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      labelStyle: TextStyle(color: secondaryLabel),
      floatingLabelStyle: TextStyle(color: primary),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: inputBorder.copyWith(borderSide: BorderSide(color: error)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 56,
      backgroundColor: surface.withValues(alpha: .94),
      indicatorColor: primary.withValues(alpha: .13),
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface.withValues(alpha: .94),
      selectedItemColor: primary,
      unselectedItemColor: secondaryLabel,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        textStyle: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: primary,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: secondaryLabel,
      textColor: primaryLabel,
      minTileHeight: 44,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: elevatedSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      modalBarrierColor: Colors.black.withValues(alpha: .34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: elevatedSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      backgroundColor: primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: primaryLabel.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: base.textTheme.bodySmall?.copyWith(color: surface),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      barBackgroundColor: surface.withValues(alpha: .88),
    ),
  );
}
