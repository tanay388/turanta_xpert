import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../availability_controller.dart';

/// The home header: who you are, when you work, and the one thing you might
/// need in a hurry.
///
/// It is the auth canvas continued — a partner signs in on this dark field and
/// lands on a screen that starts with the same one, with the content sheet
/// rising over it. One structural idea rather than a Material app bar here and
/// a custom canvas there.
///
/// Sign-out used to sit in this row, one tap from the emergency button. It
/// already exists in both Profile and Settings, so it is gone from here: a
/// destructive action does not belong next to a panic button.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.onEmergency});

  final VoidCallback onEmergency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authProvider).valueOrNull?.profile;
    final name = profile?.displayName ?? ref.t('home.default_name');
    final shift = ref.watch(attendanceProvider).currentShift?.shift;


    return ColoredBox(
      color: XpertColors.canvas,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            XpertSpacing.lg,
            XpertSpacing.md,
            XpertSpacing.lg,
            XpertSpacing.xl,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(photo: profile?.photo, name: name),
              const SizedBox(width: XpertSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: XpertTypography.display.copyWith(fontSize: 22),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shift != null) ...[
                      const SizedBox(height: 5),
                      // The one piece of context that belongs to the person
                      // rather than to today: the hours they work. Today's date
                      // moved down to the shift card, which is the thing it is
                      // actually a record of.
                      Text(
                        shift.displayWindow,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.2,
                          color: XpertColors.onCanvasMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: XpertSpacing.sm),
              _EmergencyButton(onTap: onEmergency, label: ref.t('home.emergency')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photo, required this.name});

  final String? photo;
  final String name;

  @override
  Widget build(BuildContext context) {
    // A face beats initials, initials beat a generic person icon.
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();

    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: () => context.push('/profile'),
        borderRadius: BorderRadius.circular(XpertRadius.pill),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: XpertColors.canvasSoft,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            image: photo == null || photo!.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(photo!),
                    fit: BoxFit.cover,
                  ),
          ),
          alignment: Alignment.center,
          child: photo == null || photo!.isEmpty
              ? Text(
                  initials.isEmpty ? '?' : initials,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: XpertColors.onCanvas,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

/// Deliberately the only red on the screen, and deliberately not a bare icon
/// in a row of three identical ones — if it is ever needed it has to be found
/// without looking.
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({required this.onTap, required this.label});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: XpertColors.danger.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.sos_rounded, size: 22, color: Color(0xFFFF6B6B)),
          ),
        ),
      ),
    );
  }
}
