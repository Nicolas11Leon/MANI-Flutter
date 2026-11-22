import 'package:flutter/material.dart';
import 'package:mani/core/theme/mani_transiciones.dart';
import 'package:mani/core/theme/tokens/mani_tokens.dart';

export 'package:mani/core/theme/mani_theme_controller.dart';
export 'package:mani/core/theme/tokens/mani_tokens.dart';

/// Tema de MANI — Neo-Brutalismo «La ficha sellada», construido sobre los
/// tokens de `lib/core/theme/tokens/` (colores, espaciado, forma, tipografía
/// y movimiento), disponible en Modo Claro ([light]) y Modo Oscuro ([dark]).
class AppTheme {
  AppTheme._();

  static ThemeData get light => _construir(
    brightness: Brightness.light,
    tokens: ManiTokens.claro,
    colorScheme: const ColorScheme.light(
      primary: ManiColors.brand,
      onPrimary: ManiColors.onBrand,
      primaryContainer: ManiColors.brandSoft,
      onPrimaryContainer: ManiColors.ink,
      secondary: ManiColors.accent,
      onSecondary: ManiColors.onInk,
      tertiary: ManiColors.info,
      onTertiary: ManiColors.onInk,
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
  );

  static ThemeData get dark => _construir(
    brightness: Brightness.dark,
    tokens: ManiTokens.oscuro,
    colorScheme: const ColorScheme.dark(
      primary: ManiDarkColors.brand,
      onPrimary: ManiDarkColors.onBrand,
      primaryContainer: ManiDarkColors.brandSoft,
      onPrimaryContainer: ManiDarkColors.ink,
      secondary: ManiColors.accent,
      onSecondary: ManiColors.onInk,
      tertiary: ManiColors.info,
      onTertiary: ManiColors.onInk,
      surface: ManiDarkColors.surface,
      onSurface: ManiDarkColors.ink,
      onSurfaceVariant: ManiDarkColors.inkMuted,
      surfaceContainerLowest: ManiDarkColors.background,
      surfaceContainerLow: ManiDarkColors.surface,
      surfaceContainer: ManiDarkColors.surfaceMuted,
      surfaceContainerHigh: ManiDarkColors.surfaceMuted,
      surfaceContainerHighest: ManiDarkColors.surfaceWarm,
      outline: ManiDarkColors.border,
      outlineVariant: ManiDarkColors.borderSubtle,
      error: ManiColors.danger,
      onError: ManiColors.onInk,
      errorContainer: Color(0xFF451215),
      onErrorContainer: Color(0xFFFECACA),
      scrim: ManiColors.scrim,
    ),
  );

  static ThemeData _construir({
    required Brightness brightness,
    required ManiTokens tokens,
    required ColorScheme colorScheme,
  }) {
    final baseTextTheme = ManiText.textTheme();
    final textTheme = baseTextTheme.apply(
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    );

    final side = BorderSide(color: tokens.border, width: ManiBorder.regular);
    final sideThin = BorderSide(color: tokens.border, width: ManiBorder.thin);
    final sideThick = BorderSide(color: tokens.border, width: ManiBorder.thick);

    OutlineInputBorder campo(Color color, double ancho) => OutlineInputBorder(
      borderRadius: ManiRadius.brMd,
      borderSide: BorderSide(color: color, width: ancho),
    );

    final formaControl = RoundedRectangleBorder(
      borderRadius: ManiRadius.brMd,
      side: side,
    );
    const paddingBoton = EdgeInsets.symmetric(
      horizontal: ManiSpace.xl,
      vertical: 14,
    );
    final estiloBoton = ManiText.label.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
      color: tokens.onBrand,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: tokens.background,
      extensions: [tokens],
      pageTransitionsTheme: maniPageTransitionsTheme,
      colorScheme: colorScheme,
      focusColor: tokens.ink.withValues(alpha: 0.14),
      hoverColor: tokens.ink.withValues(alpha: 0.06),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: ManiText.title.copyWith(color: tokens.ink),
        shape: Border(bottom: side),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: ManiSpace.sm),
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brLg,
          side: side,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surface,
        selectedColor: tokens.brand,
        secondarySelectedColor: tokens.brand,
        disabledColor: tokens.borderSubtle,
        checkmarkColor: tokens.onBrand,
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: ManiSpace.xs,
        ),
        side: sideThin,
        shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
        labelStyle: ManiText.caption.copyWith(
          fontWeight: FontWeight.w800,
          color: tokens.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          disabledBackgroundColor: tokens.borderSubtle,
          disabledForegroundColor: tokens.inkMuted,
          elevation: 0,
          padding: paddingBoton,
          textStyle: estiloBoton,
          shape: formaControl,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.brand,
          foregroundColor: tokens.onBrand,
          disabledBackgroundColor: tokens.borderSubtle,
          disabledForegroundColor: tokens.inkMuted,
          elevation: 0,
          padding: paddingBoton,
          textStyle: estiloBoton,
          shape: formaControl,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: tokens.surface,
          foregroundColor: tokens.ink,
          disabledForegroundColor: tokens.inkSubtle,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          textStyle: ManiText.label.copyWith(color: tokens.ink),
          side: side,
          shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.ink,
          textStyle: ManiText.label.copyWith(color: tokens.ink),
          shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: tokens.ink,
          shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ManiSpace.lg,
          vertical: 14,
        ),
        labelStyle: ManiText.label.copyWith(
          fontWeight: FontWeight.w700,
          color: tokens.ink,
        ),
        floatingLabelStyle: ManiText.label.copyWith(color: tokens.ink),
        hintStyle: ManiText.bodySm.copyWith(color: tokens.inkSubtle),
        helperStyle: ManiText.caption.copyWith(color: tokens.inkMuted),
        errorStyle: ManiText.caption.copyWith(
          color: colorScheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: tokens.inkMuted,
        suffixIconColor: tokens.inkMuted,
        border: campo(tokens.border, ManiBorder.regular),
        enabledBorder: campo(tokens.border, ManiBorder.regular),
        disabledBorder: campo(tokens.borderSubtle, ManiBorder.regular),
        focusedBorder: campo(tokens.border, 3),
        errorBorder: campo(ManiColors.danger, ManiBorder.regular),
        focusedErrorBorder: campo(ManiColors.danger, 3),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brLg,
          side: sideThick,
        ),
        titleTextStyle: ManiText.title.copyWith(color: tokens.ink),
        contentTextStyle: ManiText.body.copyWith(color: tokens.ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: tokens.ink,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(ManiRadius.lg),
          ),
          side: side,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brMd,
          side: side,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(tokens.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          side: WidgetStatePropertyAll(side),
          shape: const WidgetStatePropertyAll(
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
      dividerTheme: DividerThemeData(
        color: tokens.borderSubtle,
        thickness: ManiBorder.thin,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: tokens.ink,
        textColor: tokens.ink,
        titleTextStyle: ManiText.subtitle.copyWith(color: tokens.ink),
        subtitleTextStyle: ManiText.bodySm.copyWith(color: tokens.inkMuted),
        shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brMd),
      ),
      checkboxTheme: CheckboxThemeData(
        side: side,
        shape: const RoundedRectangleBorder(borderRadius: ManiRadius.brXs),
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? tokens.brand : tokens.surface,
        ),
        checkColor: WidgetStatePropertyAll(tokens.onBrand),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? tokens.borderSubtle
              : tokens.ink,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? tokens.onBrand
              : tokens.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? tokens.brand
              : tokens.surfaceMuted,
        ),
        trackOutlineColor: WidgetStatePropertyAll(tokens.border),
        trackOutlineWidth: const WidgetStatePropertyAll(ManiBorder.regular),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.ink,
        linearTrackColor: tokens.brandSoft,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tokens.ink,
        unselectedLabelColor: tokens.inkMuted,
        labelStyle: ManiText.label.copyWith(color: tokens.ink),
        unselectedLabelStyle: ManiText.label.copyWith(
          fontWeight: FontWeight.w600,
          color: tokens.inkMuted,
        ),
        indicatorColor: tokens.ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: tokens.borderSubtle,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.brand,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brSm,
          side: side,
        ),
        selectedIconTheme: IconThemeData(color: tokens.onBrand),
        unselectedIconTheme: IconThemeData(color: tokens.inkMuted),
        selectedLabelTextStyle: ManiText.caption.copyWith(
          fontWeight: FontWeight.w900,
          color: tokens.ink,
        ),
        unselectedLabelTextStyle: ManiText.caption.copyWith(
          color: tokens.inkMuted,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: tokens.brand,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: ManiRadius.brSm,
          side: side,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => ManiText.caption.copyWith(
            color: tokens.ink,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w900
                : FontWeight.w600,
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(tokens.surfaceMuted),
        headingTextStyle: ManiText.overline.copyWith(color: tokens.ink),
        dataTextStyle: ManiText.body.copyWith(color: tokens.ink),
        dividerThickness: 1,
        decoration: maniDecoracion(
          color: tokens.surface,
          borde: tokens.border,
          sombra: null,
          radio: ManiRadius.brMd,
        ),
      ),
    );
  }
}
