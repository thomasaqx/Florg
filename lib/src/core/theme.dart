import 'package:flutter/material.dart';

/// Tokens de marca do FLORG.
///
/// Os valores vêm da identidade da landing (florg.florg-landing.workers.dev):
/// preto esverdeado no fundo, verde petróleo como único acento, off-white no
/// texto e borda quase invisível. Nada de azul corporativo, roxo ou neon.
///
/// Tela nenhuma escreve `Color(0x...)`: o que existe aqui é o vocabulário
/// inteiro. Uma cor nova entra neste arquivo ou não entra.
abstract final class FlorgPalette {
  // Base — o preto do FLORG é verde, não cinza.
  static const ink = Color(0xFF061B19);
  static const inkDeep = Color(0xFF040F0E);
  static const surface = Color(0xFF092622);
  static const surfaceRaised = Color(0xFF0D312C);
  static const surfaceSunken = Color(0xFF071F1C);

  // Acento — verde petróleo da marca, com um passo claro e um escuro.
  static const green = Color(0xFF0A8F78);
  static const greenBright = Color(0xFF14B88F);
  static const greenSoft = Color(0xFF5FD3B2);
  static const greenDeep = Color(0xFF06644F);

  // Texto.
  static const offWhite = Color(0xFFF2F3F1);
  static const mist = Color(0xFFAEB7B4);
  static const slate = Color(0xFF6E7B78);

  // Estado. Discretos de propósito: num extrato, vermelho é informação, não
  // alarme.
  static const positive = Color(0xFF3DBE8B);
  static const caution = Color(0xFFD9A441);
  static const negative = Color(0xFFD9645F);

  // Texto e traço sobre o verde cheio de um card de destaque. Branco com
  // alpha, porque um cinza fixo brigaria com o gradiente por baixo.
  static const onAccent = Color(0xFFFFFFFF);
  static const onAccentMuted = Color(0xE6FFFFFF);
  static const onAccentSubtle = Color(0xCCFFFFFF);
  static const onAccentLine = Color(0x33FFFFFF);

  // Claro — o FLORG é dark-first; este é o modo alternativo.
  static const lightBackground = Color(0xFFF4F6F4);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFEDF2F0);
  static const lightInk = Color(0xFF07201C);
  static const lightMist = Color(0xFF52605C);
}

/// Espaçamento em passos de 4. Evita o `SizedBox(height: 13)` avulso.
abstract final class FlorgSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Raios curtos: a marca usa 3–8px, não cápsula.
abstract final class FlorgRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const pill = 999.0;
}

/// Larguras onde o layout muda de forma, não só de tamanho.
abstract final class FlorgBreakpoints {
  static const mobile = 600.0;
  static const tablet = 900.0;
  static const desktop = 1200.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mobile && width < tablet;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
}

/// Os tokens resolvidos para o brilho atual.
///
/// Fica no [ThemeData] via [ThemeExtension], então widget nenhum precisa
/// perguntar se está no escuro para escolher uma cor.
@immutable
class FlorgColors extends ThemeExtension<FlorgColors> {
  const FlorgColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSunken,
    required this.primary,
    required this.primaryMuted,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.borderStrong,
    required this.success,
    required this.warning,
    required this.error,
    required this.onPrimary,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSunken;
  final Color primary;

  /// Verde rebaixado, para preencher sem virar botão.
  final Color primaryMuted;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color borderStrong;
  final Color success;
  final Color warning;
  final Color error;
  final Color onPrimary;

  static const dark = FlorgColors(
    background: FlorgPalette.ink,
    surface: FlorgPalette.surface,
    surfaceElevated: FlorgPalette.surfaceRaised,
    surfaceSunken: FlorgPalette.surfaceSunken,
    primary: FlorgPalette.green,
    primaryMuted: Color(0x1F0A8F78),
    secondary: FlorgPalette.greenSoft,
    textPrimary: FlorgPalette.offWhite,
    textSecondary: FlorgPalette.mist,
    textMuted: FlorgPalette.slate,
    border: Color(0x1AF2F3F1),
    borderStrong: Color(0x33F2F3F1),
    success: FlorgPalette.positive,
    warning: FlorgPalette.caution,
    error: FlorgPalette.negative,
    onPrimary: Color(0xFFFFFFFF),
  );

  static const light = FlorgColors(
    background: FlorgPalette.lightBackground,
    surface: FlorgPalette.lightSurface,
    surfaceElevated: FlorgPalette.lightSurfaceRaised,
    surfaceSunken: FlorgPalette.lightSurfaceRaised,
    primary: FlorgPalette.greenDeep,
    primaryMuted: Color(0x140A8F78),
    secondary: FlorgPalette.green,
    textPrimary: FlorgPalette.lightInk,
    textSecondary: FlorgPalette.lightMist,
    textMuted: FlorgPalette.slate,
    border: Color(0x1A07201C),
    borderStrong: Color(0x3307201C),
    success: Color(0xFF17795A),
    warning: Color(0xFF9A6B10),
    error: Color(0xFFB3403B),
    onPrimary: Color(0xFFFFFFFF),
  );

  @override
  FlorgColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceSunken,
    Color? primary,
    Color? primaryMuted,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? borderStrong,
    Color? success,
    Color? warning,
    Color? error,
    Color? onPrimary,
  }) {
    return FlorgColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      primary: primary ?? this.primary,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      secondary: secondary ?? this.secondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      onPrimary: onPrimary ?? this.onPrimary,
    );
  }

  @override
  FlorgColors lerp(ThemeExtension<FlorgColors>? other, double t) {
    if (other is! FlorgColors) return this;
    return FlorgColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
    );
  }
}

extension FlorgThemeContext on BuildContext {
  /// `context.colors.primary` em vez de `AppColors.accentText(context)`.
  FlorgColors get colors =>
      Theme.of(this).extension<FlorgColors>() ?? FlorgColors.dark;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Ponte para o código que ainda chama `AppColors.x(context)`.
///
/// Encaminha para os tokens; não guarda cor própria. Some quando a última
/// chamada for convertida.
abstract final class AppColors {
  static bool isDark(BuildContext context) => context.isDark;

  static Color scaffold(BuildContext context) => context.colors.background;
  static Color surface(BuildContext context) => context.colors.surface;
  static Color sidebarSurface(BuildContext context) =>
      context.isDark ? FlorgPalette.inkDeep : FlorgPalette.lightSurface;
  static Color border(BuildContext context) => context.colors.border;
  static Color tableHeader(BuildContext context) =>
      context.colors.surfaceElevated;
  static Color subtleFill(BuildContext context) =>
      context.colors.surfaceElevated;
  static Color inputFill(BuildContext context) => context.colors.surfaceSunken;
  static Color primaryText(BuildContext context) => context.colors.textPrimary;
  static Color secondaryText(BuildContext context) =>
      context.colors.textSecondary;
  static Color accentText(BuildContext context) =>
      context.isDark ? FlorgPalette.greenSoft : FlorgPalette.greenDeep;
  static Color navText(BuildContext context) => context.colors.textSecondary;
  static Color adaptBorder(BuildContext context, Color _) =>
      context.colors.border;

  // Nomes herdados das telas. Resolvem para a paleta da marca, então um
  // `AppColors.rose500` esquecido num badge sai vermelho do FLORG, não
  // vermelho de framework.
  static const teal50 = FlorgPalette.surfaceSunken;
  static const teal100 = FlorgPalette.surfaceRaised;
  static const teal300 = FlorgPalette.greenSoft;
  static const teal400 = FlorgPalette.greenBright;
  static const teal500 = FlorgPalette.green;
  static const teal600 = FlorgPalette.green;
  static const teal700 = FlorgPalette.greenDeep;
  static const teal900 = FlorgPalette.lightInk;
  static const emerald100 = Color(0x1F3DBE8B);
  static const emerald500 = FlorgPalette.positive;
  static const emerald600 = FlorgPalette.positive;
  static const emerald700 = Color(0xFF17795A);
  static const rose100 = Color(0x1FD9645F);
  static const rose500 = FlorgPalette.negative;
  static const rose600 = FlorgPalette.negative;
  static const rose700 = Color(0xFFB3403B);
  static const amber100 = Color(0x1FD9A441);
  static const amber500 = FlorgPalette.caution;
  static const amber600 = FlorgPalette.caution;
  static const amber700 = Color(0xFF9A6B10);
  static const gray400 = FlorgPalette.slate;
  static const gray500 = FlorgPalette.slate;

  /// Cores de série dos gráficos, na ordem em que devem ser usadas.
  ///
  /// Começa no verde da marca e abre em tons vizinhos. Sem roxo, sem azul
  /// corporativo e sem duas cores que se confundam lado a lado.
  static const chartSeries = <Color>[
    FlorgPalette.green,
    FlorgPalette.greenSoft,
    Color(0xFF3F8F86),
    FlorgPalette.caution,
    Color(0xFF7FB79C),
    FlorgPalette.negative,
    Color(0xFF2E6F63),
    Color(0xFFB8C4BF),
    Color(0xFF16A085),
    Color(0xFF8A9B4F),
    Color(0xFF4E7D74),
  ];

  static LinearGradient helpGradient(BuildContext context) => LinearGradient(
    colors: context.isDark
        ? const [FlorgPalette.surfaceRaised, FlorgPalette.surface]
        : const [FlorgPalette.lightSurfaceRaised, FlorgPalette.lightSurface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Tipografia da marca: pesos médios, tamanhos grandes e letter-spacing
/// negativo nos títulos; rótulo em caixa alta bem espaçada.
abstract final class FlorgText {
  static const _family = null; // sans do sistema; a marca usa Inter na web.

  static TextTheme themeFor(FlorgColors colors) {
    return TextTheme(
      displaySmall: TextStyle(
        fontFamily: _family,
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.4,
        color: colors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: 30,
        height: 1.1,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.0,
        color: colors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.6,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: colors.textPrimary),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        color: colors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.45,
        color: colors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      // O rótulo de card do FLORG: 11px, caixa alta, bem espaçado.
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.0,
        color: colors.textSecondary,
      ),
    );
  }

  /// Número grande de card (saldo, total do mês).
  static TextStyle figure(BuildContext context, {double size = 30}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w500,
      letterSpacing: -1.0,
      height: 1.1,
      color: context.colors.textPrimary,
    );
  }
}

abstract final class FlorgTheme {
  static ThemeData light() => _build(Brightness.light, FlorgColors.light);
  static ThemeData dark() => _build(Brightness.dark, FlorgColors.dark);

  static ThemeData _build(Brightness brightness, FlorgColors colors) {
    final textTheme = FlorgText.themeFor(colors);
    final borderShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FlorgRadius.md),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      dividerColor: colors.border,
      extensions: [colors],
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FlorgPalette.green,
        brightness: brightness,
        primary: colors.primary,
        onPrimary: colors.onPrimary,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        error: colors.error,
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: brightness == Brightness.dark
            ? FlorgPalette.inkDeep
            : FlorgPalette.lightSurface,
        indicatorColor: colors.primaryMuted,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: FlorgSpacing.lg,
            vertical: 14,
          ),
          shape: borderShape,
          textStyle: textTheme.labelLarge?.copyWith(color: colors.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(
            horizontal: FlorgSpacing.md,
            vertical: 14,
          ),
          shape: borderShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.secondary),
      ),
      iconTheme: IconThemeData(color: colors.textSecondary, size: 20),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: borderShape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorgRadius.lg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceElevated,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: borderShape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceElevated,
        circularTrackColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FlorgSpacing.md,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorgRadius.md),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorgRadius.md),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorgRadius.md),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlorgRadius.md),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
      ),
    );
  }
}

/// Gradiente do acento. Curto e de baixo contraste: o verde marca o elemento,
/// não compete com o conteúdo.
const primaryGradient = LinearGradient(
  colors: [FlorgPalette.green, FlorgPalette.greenDeep],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const tealCyanGradient = primaryGradient;
const tealEmeraldGradient = primaryGradient;
