import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inkflow/core/theme/app_theme.dart';

// ─────────────────────────────────────────────
// InkFlowLogo — logo com cor configurável (branco em fundos escuros)
// ─────────────────────────────────────────────
class InkFlowLogo extends StatelessWidget {
  final double height;
  final Color color;

  const InkFlowLogo({
    super.key,
    this.height = 28,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      child: Image.asset(
        'assets/inkflow_logo.png',
        height: height,
        errorBuilder: (c, e, s) =>
            Icon(Icons.water_drop, color: color, size: height),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ScenarioSwitcher — barra de cenários de RF
// ─────────────────────────────────────────────
class ScenarioConfig {
  final String key;
  final String label;
  final ScenarioColor color;
  const ScenarioConfig({required this.key, required this.label, required this.color});
}

enum ScenarioColor { green, red, yellow }

class ScenarioSwitcher extends StatelessWidget {
  final String rf;
  final String active;
  final List<ScenarioConfig> scenarios;
  final ValueChanged<String> onChange;

  const ScenarioSwitcher({
    super.key,
    required this.rf,
    required this.active,
    required this.scenarios,
    required this.onChange,
  });

  Color _bg(ScenarioColor c, bool isActive) {
    if (isActive) {
      return switch (c) {
        ScenarioColor.green => const Color(0xFF10B981),
        ScenarioColor.red => const Color(0xFFEF4444),
        ScenarioColor.yellow => const Color(0xFFF59E0B),
      };
    }
    return switch (c) {
      ScenarioColor.green => const Color(0xFF10B981).withOpacity(0.2),
      ScenarioColor.red => const Color(0xFFEF4444).withOpacity(0.2),
      ScenarioColor.yellow => const Color(0xFFF59E0B).withOpacity(0.2),
    };
  }

  Color _fg(ScenarioColor c, bool isActive) {
    if (isActive) return Colors.white;
    return switch (c) {
      ScenarioColor.green => const Color(0xFF10B981),
      ScenarioColor.red => const Color(0xFFEF4444),
      ScenarioColor.yellow => const Color(0xFFF59E0B),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: InkFlowColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              rf,
              style: const TextStyle(
                color: InkFlowColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 8),
            ...scenarios.map((s) {
              final isActive = s.key == active;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => onChange(s.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _bg(s.color, isActive),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _bg(s.color, !isActive)),
                    ),
                    child: Text(
                      s.label,
                      style: TextStyle(
                        color: _fg(s.color, isActive),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
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
    return Container(
      color: dark ? InkFlowColors.primary : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (showBack)
            GestureDetector(
              onTap: () {
                if (backTo != null) {
                  context.go(backTo!);
                } else {
                  context.pop();
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.chevron_left,
                  color: dark ? Colors.white : Colors.grey.shade700,
                  size: 20,
                ),
              ),
            )
          else
            InkFlowLogo(
              height: 28,
              color: dark ? Colors.white : InkFlowColors.primary,
            ),
          if (title != null) ...[
            const SizedBox(width: 12),
            Text(
              title!,
              style: TextStyle(
                color: dark ? Colors.white : Colors.grey.shade900,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const Spacer(),
          if (rightElement != null) rightElement!,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BottomNav — barra de navegação inferior
// ─────────────────────────────────────────────
class BottomNav extends StatelessWidget {
  final int currentIndex;

  const BottomNav({super.key, required this.currentIndex});

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Início', path: '/home'),
    _NavItem(icon: Icons.calendar_today_rounded, label: 'Agenda', path: '/schedule'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'Chat', path: '/chat'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil', path: '/profile-setup'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => context.go(item.path),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        color: isActive ? InkFlowColors.primary : Colors.grey.shade400,
                        size: 22,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isActive ? InkFlowColors.primary : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}

// ─────────────────────────────────────────────
// StatusBadge — badge reutilizável
// ─────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.bgColor,
    required this.textColor,
  });

  factory StatusBadge.anamnesis(bool ok, {bool risk = false}) {
    if (risk) {
      return const StatusBadge(
        text: 'Condição de Risco',
        bgColor: Color(0xFFFEE2E2),
        textColor: Color(0xFFDC2626),
      );
    }
    return StatusBadge(
      text: ok ? 'Anamnese OK' : 'Pendente',
      bgColor: ok ? const Color(0xFFDBEAFE) : const Color(0xFFFEF3C7),
      textColor: ok ? const Color(0xFF2563EB) : const Color(0xFFD97706),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SkeletonLoader — placeholder animado (RNF04)
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
    return AnimatedBuilder(
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
// InkTextField — input field reutilizável (dark)
// ─────────────────────────────────────────────
class InkTextField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final String? errorText;
  final String? hint;
  final bool enabled;

  const InkTextField({
    super.key,
    required this.label,
    this.initialValue,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.hasError = false,
    this.errorText,
    this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444).withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444).withOpacity(0.6)
                    : Colors.white.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : InkFlowColors.accent.withOpacity(0.6),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (hasError && errorText != null) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 11),
          ),
        ],
      ],
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

  const InkButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isOutlined = false,
    this.isLoading = false,
    this.width,
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
              ? Colors.white.withOpacity(0.1)
              : isOutlined
                  ? Colors.transparent
                  : InkFlowColors.accent,
          foregroundColor: isDisabled
              ? Colors.white.withOpacity(0.3)
              : isOutlined
                  ? InkFlowColors.accent
                  : InkFlowColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOutlined
                ? BorderSide(color: InkFlowColors.accent.withOpacity(0.4))
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
                      ? Colors.white.withOpacity(0.3)
                      : isOutlined
                          ? InkFlowColors.accent
                          : InkFlowColors.primary,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AvatarImage — foto circular com rede
// ─────────────────────────────────────────────
class AvatarImage extends StatelessWidget {
  final String url;
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
                color: InkFlowColors.accent.withOpacity(0.3),
                width: borderWidth,
              )
            : null,
      ),
      child: ClipOval(
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey.shade700,
            child: Icon(
              Icons.person,
              color: Colors.grey.shade400,
              size: size * 0.6,
            ),
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(color: Colors.grey.shade800);
          },
        ),
      ),
    );
  }
}
