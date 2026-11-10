import 'package:flutter/material.dart';
import 'package:mani/core/theme/tokens/mani_tokens.dart';

export 'package:mani/core/theme/tokens/mani_tokens.dart';

/// Tema de MANI — Neo-Brutalismo del Figma oficial, construido sobre los
/// tokens de `lib/core/theme/tokens/` (colores, espaciado, forma, tipografía
/// y movimiento). Ningún valor visual se declara aquí: todos salen de ellos.
class AppTheme {
  AppTheme._();

  // ── Alias heredados ───────────────────────────────────────────────────────
  // Nombres anteriores a los tokens, mantenidos mientras termina la migración.
  // Código nuevo: usar `ManiColors`, `ManiShadow` y `ManiRadius`.
  static const Color background = ManiColors.background;
  static const Color surface = ManiColors.surface;
  static const Color primary = ManiColors.brand;
  static const Color dark = ManiColors.ink;
  static const Color textPrimary = ManiColors.ink;
  static const Color textSecondary = ManiColors.inkMuted;
  static const Color textTertiary = ManiColors.inkSubtle;
  static const Color borderLight = ManiColors.borderSubtle;
  static const Color success = ManiColors.success;
  static const Color error = ManiColors.danger;
  static const BoxShadow hardShadowSm = ManiShadow.sm;
  static const BoxShadow hardShadowMd = ManiShadow.md;
  static const BoxShadow hardShadowLg = ManiShadow.lg;
  static const double radiusSm = ManiRadius.xs;
  static const double radiusMd = ManiRadius.sm;
  static const double radiusXl = ManiRadius.md;
  static const double radius2xl = ManiRadius.lg;

  static ThemeData get light {
    // Sin `fontFamily` global a propósito: ThemeData la aplicaría sobre todo
    // el textTheme y cada peso volvería al archivo regular (negrita sintética).
    // Cada estilo del textTheme ya trae la familia de su variante.
    final textTheme = ManiText.textTheme();

    OutlineInputBorder campo(Color color, double ancho) => OutlineInputBorder(
      borderRadius: ManiRadius.brMd,
      borderSide: BorderSide(color: color, width: ancho),
    );

    const formaControl = RoundedRectangleBorder(
      borderRadius: ManiRadius.brMd,
      side: ManiBorder.side,
    );
    const paddingBoton = EdgeInsets.symmetric(
      horizontal: ManiSpace.xl,
      vertical: 14,
    );
    final estiloBoton = ManiText.label.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
    );

    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: ManiColors.background,
      extensions: const [ManiTokens.claro],
      colorScheme: const ColorScheme.light(
        primary: ManiColors.brand,
        onPrimary: ManiColors.onBrand,
        primaryContainer: ManiColors.brandSoft,
        onPrimaryContainer: ManiColors.ink,
        secondary: ManiColors.ink,
        onSecondary: ManiColors.onInk,
        surface: ManiColors.surface,
        onSurface: ManiColors.ink,
        onSurfaceVariant: ManiColors.inkMuted,
        surfaceContainerLowest: ManiColors.surface,
        surfaceContainerLow: ManiColors.background,
        surfaceContainer: ManiColors.surfaceMuted,
        surfaceContainerHigh: ManiColors.surfaceMuted,
        surfaceContainerHighest: ManiColors.surfaceWarm,
        outline: ManiColors.border,
        outlineVariant: ManiColors.borderSubtle,
        error: ManiColors.danger,
        onError: ManiColors.onInk,
        errorContainer: ManiColors.dangerContainer,
        onErrorContainer: ManiColors.dangerText,
        scrim: ManiColors.scrim,
      ),
      // Foco de teclado visible: el overlay de foco de Material se oscurece
      // lo bastante para notarse sobre amarillo, blanco y crema.
      focusColor: ManiColors.ink.withValues(alpha: 0.14),
      hoverColor: ManiColors.ink.withValues(alpha: 0.05),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: ManiColors.surface,
        foregroundColor: ManiColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: ManiText.title,
        shape: const Border(bottom: ManiBorder.side),
      ),
      cardTheme: const CardThemeData(
        color: ManiColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.symmetric(vertical: ManiSpace.sm),
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brLg,
          side: ManiBorder.side,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ManiColors.surface,
        selectedColor: ManiColors.brand,
        secondarySelectedColor: ManiColors.brand,
        disabledColor: ManiColors.borderSubtle,
        checkmarkColor: ManiColors.ink,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: ManiSpace.xs,
        ),
        side: ManiBorder.sideThin,
        shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
        labelStyle: ManiText.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: ManiColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ManiColors.brand,
          foregroundColor: ManiColors.onBrand,
          disabledBackgroundColor: ManiColors.borderSubtle,
          disabledForegroundColor: ManiColors.inkMuted,
          elevation: 0,
          padding: paddingBoton,
          textStyle: estiloBoton,
          shape: formaControl,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ManiColors.brand,
          foregroundColor: ManiColors.onBrand,
          disabledBackgroundColor: ManiColors.borderSubtle,
          disabledForegroundColor: ManiColors.inkMuted,
          elevation: 0,
          padding: paddingBoton,
          textStyle: estiloBoton,
          shape: formaControl,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: ManiColors.surface,
          foregroundColor: ManiColors.ink,
          disabledForegroundColor: ManiColors.inkSubtle,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: ManiText.label,
          side: ManiBorder.side,
          shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ManiColors.ink,
          textStyle: ManiText.label,
          shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ManiColors.ink,
          shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ManiColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ManiSpace.lg,
          vertical: 14,
        ),
        labelStyle: ManiText.label.copyWith(fontWeight: FontWeight.w700),
        floatingLabelStyle: ManiText.label,
        hintStyle: ManiText.bodySm.copyWith(color: ManiColors.inkSubtle),
        helperStyle: ManiText.caption,
        errorStyle: ManiText.caption.copyWith(
          color: ManiColors.dangerText,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: ManiColors.inkMuted,
        suffixIconColor: ManiColors.inkMuted,
        border: campo(ManiColors.border, ManiBorder.regular),
        enabledBorder: campo(ManiColors.border, ManiBorder.regular),
        disabledBorder: campo(ManiColors.borderSubtle, ManiBorder.regular),
        focusedBorder: campo(ManiColors.border, 3),
        errorBorder: campo(ManiColors.danger, ManiBorder.regular),
        focusedErrorBorder: campo(ManiColors.danger, 3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: ManiColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: ManiRadius.brLg,
          side: ManiBorder.sideThick,
        ),
        titleTextStyle: ManiText.title,
        contentTextStyle: ManiText.body,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ManiColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: ManiColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(ManiRadius.lg),
          ),
          side: ManiBorder.side,
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: ManiColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brMd,
          side: ManiBorder.side,
        ),
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(ManiColors.surface),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(ManiBorder.side),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: ManiRadius.brMd),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ManiColors.ink,
        contentTextStyle: ManiText.label.copyWith(
          fontWeight: FontWeight.w700,
          color: ManiColors.onInk,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: ManiRadius.brMd,
          side: BorderSide(color: ManiColors.brand, width: ManiBorder.regular),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: ManiColors.ink,
          borderRadius: ManiRadius.brSm,
        ),
        textStyle: ManiText.caption.copyWith(
          color: ManiColors.onInk,
          fontWeight: FontWeight.w700,
        ),
        waitDuration: ManiMotion.slow,
      ),
      dividerTheme: const DividerThemeData(
        color: ManiColors.ink,
        thickness: ManiBorder.thin,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: ManiColors.ink,
        textColor: ManiColors.ink,
        titleTextStyle: ManiText.subtitle,
        subtitleTextStyle: ManiText.bodySm,
        shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brMd),
      ),
      checkboxTheme: CheckboxThemeData(
        side: ManiBorder.side,
        shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brXs),
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ManiColors.brand
              : ManiColors.surface,
        ),
        checkColor: const WidgetStatePropertyAll(ManiColors.ink),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? ManiColors.borderSubtle
              : ManiColors.ink,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ManiColors.ink
              : ManiColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? ManiColors.brand
              : ManiColors.surfaceMuted,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(ManiColors.ink),
        trackOutlineWidth: const WidgetStatePropertyAll(ManiBorder.regular),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ManiColors.ink,
        linearTrackColor: ManiColors.brandSoft,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ManiColors.ink,
        unselectedLabelColor: ManiColors.inkMuted,
        labelStyle: ManiText.label,
        unselectedLabelStyle: ManiText.label.copyWith(
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: ManiColors.ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: ManiColors.borderSubtle,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: ManiColors.surface,
        indicatorColor: ManiColors.brand,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: ManiRadius.brSm,
          side: ManiBorder.side,
        ),
        selectedIconTheme: const IconThemeData(color: ManiColors.ink),
        unselectedIconTheme: const IconThemeData(color: ManiColors.inkMuted),
        selectedLabelTextStyle: ManiText.caption.copyWith(
          fontWeight: FontWeight.w900,
          color: ManiColors.ink,
        ),
        unselectedLabelTextStyle: ManiText.caption,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ManiColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: ManiColors.brand,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: ManiRadius.brSm,
          side: ManiBorder.side,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => ManiText.caption.copyWith(
            color: ManiColors.ink,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(ManiColors.surfaceMuted),
        headingTextStyle: ManiText.overline,
        dataTextStyle: ManiText.body,
        dividerThickness: 1,
        decoration: maniDecoracion(sombra: null, radio: ManiRadius.brMd),
      ),
    );
  }
}
