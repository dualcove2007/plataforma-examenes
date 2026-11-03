import 'package:flutter/material.dart';

/// Paleta plana (sin degradados): crema de fondo, tinta oscura para texto
/// y colores vivos que se repiten como "pastillas" de cada sección.
class Paleta {
  static const crema = Color(0xFFFFF8EE);
  static const tinta = Color(0xFF1F2A37);
  static const tintaSuave = Color(0xFF5B6675);
  static const borde = Color(0x261F2A37); // tinta al 15 %

  static const verde = Color(0xFF1F7A6D);
  static const verdeClaro = Color(0xFF2E9384);
  static const verdeSuave = Color(0xFFD6EFE8);

  static const miel = Color(0xFFFFC145);
  static const mielSuave = Color(0xFFFFEBC2);

  static const coral = Color(0xFFFF6B5E);
  static const coralSuave = Color(0xFFFFDAD5);

  static const cielo = Color(0xFF5BB8E8);
  static const cieloSuave = Color(0xFFD3ECFA);

  static const lila = Color(0xFFA78BFA);
  static const lilaSuave = Color(0xFFE7DFFD);
}

/// Color de cabecera de cada sección del panel.
class Seccion {
  final Color fondo; // color de la cabecera
  final Color deco; // círculos decorativos (plano, un tono más claro)
  final Color texto;
  const Seccion(this.fondo, this.deco, this.texto);

  static const inicio = Seccion(Paleta.verde, Paleta.verdeClaro, Colors.white);
  static const usuarios = Seccion(
    Paleta.cielo,
    Color(0xFF82CCF0),
    Paleta.tinta,
  );
  static const materias = Seccion(Paleta.miel, Color(0xFFFFD375), Paleta.tinta);
  static const roles = Seccion(Paleta.lila, Color(0xFFBDA6FB), Paleta.tinta);
  static const auditoria = Seccion(
    Paleta.coral,
    Color(0xFFFF8A7F),
    Paleta.tinta,
  );
}

/// Ícono y color que identifican a cada rol en toda la app.
class EstiloRol {
  final IconData icono;
  final Color color;
  final Color suave;
  const EstiloRol(this.icono, this.color, this.suave);

  static EstiloRol de(String? rol) {
    switch (rol) {
      case 'Administrador':
        return const EstiloRol(
          Icons.admin_panel_settings_rounded,
          Paleta.lila,
          Paleta.lilaSuave,
        );
      case 'Docente':
        return const EstiloRol(
          Icons.cast_for_education_rounded,
          Paleta.cielo,
          Paleta.cieloSuave,
        );
      case 'Estudiante':
        return const EstiloRol(
          Icons.school_rounded,
          Paleta.miel,
          Paleta.mielSuave,
        );
      default:
        return const EstiloRol(
          Icons.person_rounded,
          Paleta.verdeClaro,
          Paleta.verdeSuave,
        );
    }
  }
}

ThemeData construirTema() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Paleta.verde,
    onPrimary: Colors.white,
    secondary: Paleta.miel,
    onSecondary: Paleta.tinta,
    tertiary: Paleta.lila,
    onTertiary: Paleta.tinta,
    error: Color(0xFFD64545),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Paleta.tinta,
    outline: Paleta.borde,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Paleta.crema,
  );

  OutlineInputBorder borde(Color c, [double w = 1.5]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Paleta.tinta,
      displayColor: Paleta.tinta,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Paleta.crema,
      foregroundColor: Paleta.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Paleta.tinta,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: borde(Paleta.borde),
      enabledBorder: borde(Paleta.borde),
      focusedBorder: borde(Paleta.verde, 2),
      errorBorder: borde(scheme.error),
      focusedErrorBorder: borde(scheme.error, 2),
      labelStyle: const TextStyle(color: Paleta.tintaSuave),
      prefixIconColor: Paleta.tintaSuave,
      suffixIconColor: Paleta.tintaSuave,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: Paleta.tinta,
        side: const BorderSide(color: Paleta.borde, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Paleta.verde,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Paleta.miel,
      foregroundColor: Paleta.tinta,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Paleta.tinta, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Paleta.verdeSuave,
      side: const BorderSide(color: Paleta.borde, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Paleta.tinta,
      ),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: Paleta.mielSuave,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Paleta.tinta
              : Paleta.tintaSuave,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? Paleta.tinta
              : Paleta.tintaSuave,
        ),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Colors.white : Paleta.tintaSuave,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Paleta.verde : Paleta.crema,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Paleta.verde : Paleta.borde,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Paleta.borde, width: 1.5),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Paleta.tinta,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: const DividerThemeData(color: Paleta.borde, space: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Paleta.borde, width: 1.5),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Paleta.verde,
    ),
  );
}
