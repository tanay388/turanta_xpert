import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/i18n/context_t.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/location_api.dart';
import 'widgets/searchable_picker_screen.dart';

/// Where will you work? City, then area, then the hub itself.
///
/// Three rows that each open their own searchable screen. Chips were fine for
/// six cities and will not survive sixty: a partner needs to type two letters,
/// not scroll a wall. Answering a row clears the ones under it, because an
/// area only means something inside the city above it.
class HubSelectionScreen extends ConsumerStatefulWidget {
  const HubSelectionScreen({super.key});

  @override
  ConsumerState<HubSelectionScreen> createState() => _HubSelectionScreenState();
}

class _HubSelectionScreenState extends ConsumerState<HubSelectionScreen> {
  HubCity? _city;
  HubArea? _area;
  HubOption? _hub;
  bool _busy = false;
  String? _error;

  Future<int?> _pick({
    required String title,
    required String searchHint,
    required List<PickerOption> options,
    required String emptyText,
    int? selectedId,
  }) {
    return Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => SearchablePickerScreen(
          title: title,
          searchHint: searchHint,
          options: options,
          emptyText: emptyText,
          selectedId: selectedId,
        ),
      ),
    );
  }

  String _cityLine(HubCity city) {
    final parts = [
      if (city.state != null && city.state!.trim().isNotEmpty) city.state!,
      if (city.distanceKm != null)
        ref.t('hub.distance', {'km': city.distanceKm!.round().toString()}),
    ];
    return parts.join(' · ');
  }

  Future<void> _pickCity(List<HubCity> cities) async {
    final nearest = cities.firstOrNull;
    final id = await _pick(
      title: ref.t('hub.city'),
      searchHint: ref.t('hub.search.city'),
      selectedId: _city?.id,
      emptyText: ref.t('hub.no_cities'),
      options: [
        for (final city in cities)
          PickerOption(
            id: city.id,
            label: city.name,
            sublabel: _cityLine(city).isEmpty ? null : _cityLine(city),
            badge: city.id == nearest?.id && city.distanceKm != null
                ? ref.t('hub.nearest')
                : null,
          ),
      ],
    );
    if (id == null) return;
    setState(() {
      _city = cities.firstWhere((c) => c.id == id);
      _area = null;
      _hub = null;
      _error = null;
    });
  }

  Future<void> _pickArea() async {
    final areas = _city?.areas ?? const <HubArea>[];
    final id = await _pick(
      title: ref.t('hub.area'),
      searchHint: ref.t('hub.search.area'),
      selectedId: _area?.id,
      emptyText: ref.t('hub.no_areas'),
      options: [
        for (final area in areas) PickerOption(id: area.id, label: area.name),
      ],
    );
    if (id == null) return;
    setState(() {
      _area = areas.firstWhere((a) => a.id == id);
      _hub = null;
      _error = null;
    });
  }

  Future<void> _pickHub() async {
    final area = _area;
    if (area == null) return;

    final hubs = await ref.read(hubsInAreaProvider(area.id).future).catchError((
      _,
    ) {
      return <HubOption>[];
    });
    if (!mounted) return;

    final id = await _pick(
      title: ref.t('hub.hub'),
      searchHint: ref.t('hub.search.hub'),
      selectedId: _hub?.id,
      emptyText: ref.t('hub.no_hubs'),
      options: [
        for (final hub in hubs)
          PickerOption(id: hub.id, label: hub.name, sublabel: hub.address),
      ],
    );
    if (id == null) return;
    setState(() {
      _hub = hubs.firstWhere((h) => h.id == id);
      _error = null;
    });
  }

  Future<void> _continue() async {
    final hub = _hub;
    if (hub == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(locationApiProvider).chooseHub(hub.id);
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      final session = ref.read(authProvider).valueOrNull;
      if (session == null) {
        context.go('/login');
        return;
      }
      context.go(partnerDestination(PartnerGates.of(session)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = ref.t('hub.error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = ref.watch(hubCitiesProvider);

    return Scaffold(
      backgroundColor: XpertColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: cities.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _Retry(
                  message: ref.t('hub.load_error'),
                  onRetry: () => ref.invalidate(hubCitiesProvider),
                ),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(
                    XpertSpacing.lg,
                    XpertSpacing.xl,
                    XpertSpacing.lg,
                    XpertSpacing.lg,
                  ),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: XpertColors.heroAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(XpertRadius.md),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.place_outlined,
                          size: 22,
                          color: XpertColors.heroAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.md),
                    Text(
                      ref.t('hub.title'),
                      style: XpertTypography.title.copyWith(fontSize: 24),
                    ),
                    const SizedBox(height: XpertSpacing.xs),
                    Text(
                      ref.t('hub.subtitle'),
                      style: XpertTypography.caption.copyWith(
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: XpertSpacing.xl),

                    _ChoiceRow(
                      step: 1,
                      label: ref.t('hub.city'),
                      value: _city?.name,
                      hint: ref.t('hub.choose'),
                      enabled: !_busy,
                      onTap: () => _pickCity(list),
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                    _ChoiceRow(
                      step: 2,
                      label: ref.t('hub.area'),
                      value: _area?.name,
                      hint: _city == null
                          ? ref.t('hub.pick_city_first')
                          : ref.t('hub.choose'),
                      enabled: !_busy && _city != null,
                      onTap: _pickArea,
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                    _ChoiceRow(
                      step: 3,
                      label: ref.t('hub.hub'),
                      value: _hub?.name,
                      hint: _area == null
                          ? ref.t('hub.pick_area_first')
                          : ref.t('hub.choose'),
                      enabled: !_busy && _area != null,
                      onTap: _pickHub,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                XpertSpacing.lg,
                XpertSpacing.md,
                XpertSpacing.lg,
                XpertSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: XpertColors.surface,
                border: Border(top: BorderSide(color: Color(0xFFE8EDF1))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: XpertColors.danger,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: XpertTypography.caption.copyWith(
                              color: XpertColors.danger,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: XpertSpacing.sm),
                  ],
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _busy || _hub == null ? null : _continue,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              ref.t('hub.cta'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three answers: what it is, what was chosen, and a way in.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.step,
    required this.label,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onTap,
  });

  final int step;
  final String label;
  final String? value;
  final String hint;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final answered = value != null;
    return Material(
      color: XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(XpertSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(XpertRadius.lg),
              border: Border.all(
                color: answered
                    ? XpertColors.heroAccent
                    : XpertColors.border.withValues(alpha: 0.4),
                width: answered ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: answered
                        ? XpertColors.success.withValues(alpha: 0.12)
                        : XpertColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: answered
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: XpertColors.success,
                        )
                      : Text(
                          '$step',
                          style: XpertTypography.label.copyWith(
                            fontSize: 12,
                            color: XpertColors.muted,
                          ),
                        ),
                ),
                const SizedBox(width: XpertSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: XpertTypography.eyebrow.copyWith(
                          color: XpertColors.muted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value ?? hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: answered
                            ? XpertTypography.label.copyWith(fontSize: 15)
                            : XpertTypography.caption.copyWith(fontSize: 13.5),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: XpertColors.muted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(XpertSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: XpertTypography.caption.copyWith(fontSize: 13.5),
            ),
            const SizedBox(height: XpertSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
