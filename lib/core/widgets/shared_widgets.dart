import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:inkflow/core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// InkFlowLogo — logo com cor configurável (branco em fundos escuros)
// ─────────────────────────────────────────────
class InkFlowLogo extends StatelessWidget {
  final double height;
  final Color color;
  final bool showWordmark;

  const InkFlowLogo({
    super.key,
    this.height = 28,
    this.color = Colors.white,
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'InkFlow',
      image: true,
      // A imagem original possui fundo opaco e uma margem interna grande, que
      // virava um pequeno quadrado no cabeçalho. A marca vetorial se adapta a
      // qualquer tamanho e fundo sem perder nitidez.
      child: _InkFlowLogoFallback(
        height: height,
        color: color,
        showWordmark: showWordmark,
      ),
    );
  }
}

class _InkFlowLogoFallback extends StatelessWidget {
  final double height;
  final Color color;
  final bool showWordmark;

  const _InkFlowLogoFallback({
    required this.height,
    required this.color,
    required this.showWordmark,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = height * 0.68;
    final fontSize = height * 0.58;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(height * 0.3),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.gesture_rounded, color: color, size: iconSize),
        ),
        if (showWordmark) ...[
          SizedBox(width: height * 0.24),
          Text(
            'InkFlow.',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              height: 1,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
// UnderDevelopmentBanner — sinaliza tela com dados de demonstração
// ─────────────────────────────────────────────

/// Faixa que deixa explícito para o usuário que a tela ainda não persiste dados
/// reais.
///
/// Sem isso, telas como Dashboard e Lembretes apresentavam números fixos como
/// se fossem informação de produção.
class UnderDevelopmentBanner extends StatelessWidget {
  final String message;

  const UnderDevelopmentBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: InkFlowColors.warning.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.construction, color: Color(0xFF92400E), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppHeader — cabeçalho padrão das telas
// ─────────────────────────────────────────────
class AppHeader extends StatelessWidget {
  final String? title;
  final bool showBack;
  final String? backTo;
  final Widget? rightElement;
  final bool dark;

  const AppHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.backTo,
    this.rightElement,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? InkFlowColors.primary : InkFlowColors.background,
        border: dark
            ? null
            : const Border(bottom: BorderSide(color: InkFlowColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Row(
            children: [
              if (showBack)
                Semantics(
                  button: true,
                  label: 'Voltar',
                  child: IconButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else if (backTo != null) {
                        context.go(backTo!);
                      } else {
                        context.go('/home');
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: dark
                          ? Colors.white.withValues(alpha: .1)
                          : InkFlowColors.white,
                      side: BorderSide(
                        color: dark ? Colors.transparent : InkFlowColors.border,
                      ),
                    ),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: dark ? Colors.white : InkFlowColors.text,
                        size: 20),
                  ),
                )
              else
                InkFlowLogo(
                  height: 28,
                  color: dark ? Colors.white : InkFlowColors.primary,
                ),
              if (title != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: dark ? Colors.white : Colors.grey.shade900,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              if (rightElement != null) rightElement!,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AppBottomNav — barra principal do app
// ─────────────────────────────────────────────
class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  static const _paths = ['/home', '/schedule', '/inbox', '/profile'];

  @override
  Widget build(BuildContext context) {
    final index = currentIndex.clamp(0, _paths.length - 1);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: InkFlowColors.white,
        border: Border(top: BorderSide(color: InkFlowColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index,
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            if (i != index) context.go(_paths[i]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Início',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SkeletonLoader — placeholder animado
// ─────────────────────────────────────────────
class SkeletonLoader extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const SkeletonLoader({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              color: Color.lerp(
                Colors.grey.shade300,
                Colors.grey.shade100,
                _controller.value,
              ),
            ),
          );
        },
      ),
    );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;

  const SkeletonGrid({
    super.key,
    this.itemCount = 4,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const SkeletonLoader(height: 220),
    );
  }
}

// ─────────────────────────────────────────────
// InkButton — botão primário
// ─────────────────────────────────────────────
class InkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isOutlined;
  final bool isLoading;
  final double? width;
  final bool onDark;

  const InkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
    this.width,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? Colors.white.withValues(alpha: 0.1)
              : isOutlined
                  ? Colors.transparent
                  : onDark
                      ? InkFlowColors.accent
                      : InkFlowColors.primary,
          foregroundColor: isDisabled
              ? Colors.white.withValues(alpha: 0.3)
              : isOutlined
                  ? InkFlowColors.accent
                  : onDark
                      ? InkFlowColors.primary
                      : InkFlowColors.white,
          minimumSize: const Size(48, 54),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isOutlined
                ? BorderSide(
                    color: InkFlowColors.accent.withValues(alpha: 0.55))
                : BorderSide.none,
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDisabled
                      ? Colors.white.withValues(alpha: 0.3)
                      : isOutlined
                          ? InkFlowColors.accent
                          : onDark
                              ? InkFlowColors.primary
                              : InkFlowColors.white,
                ),
              ),
      ),
    );
  }
}

/// Limita telas de formulário em desktop/tablet sem alterar o layout mobile.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class InkSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const InkSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: InkFlowColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: InkFlowColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

// ─────────────────────────────────────────────
// Imagens de rede
// ─────────────────────────────────────────────

/// Imagem de rede com cache em disco e fallback visual.
///
/// Usa `cached_network_image`, que já era declarado no `pubspec.yaml` mas nunca
/// tinha sido usado: todas as telas chamavam `Image.network` e rebaixavam a
/// mesma foto a cada rebuild.
class NetworkImageWithFallback extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final IconData fallbackIcon;

  const NetworkImageWithFallback({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fallbackIcon = Icons.image_not_supported_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final source = url;
    if (source == null || source.isEmpty) return _fallback();

    return CachedNetworkImage(
      imageUrl: source,
      width: width,
      height: height,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
      ),
      errorWidget: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Icon(fallbackIcon, color: Colors.grey.shade400, size: 32),
    );
  }
}

/// Foto de perfil circular, com cache e fallback.
class AvatarImage extends StatelessWidget {
  final String? url;
  final double size;
  final double borderWidth;

  const AvatarImage({
    super.key,
    required this.url,
    this.size = 40,
    this.borderWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: borderWidth > 0
            ? Border.all(
                color: InkFlowColors.accent.withValues(alpha: 0.3),
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: NetworkImageWithFallback(
          url: url,
          width: size,
          height: size,
          fallbackIcon: Icons.person,
        ),
      ),
    );
  }
}
