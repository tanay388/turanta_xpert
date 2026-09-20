import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/i18n/context_t.dart';
import '../../../../core/theme/xpert_tokens.dart';

class PickerOption {
  const PickerOption({
    required this.id,
    required this.label,
    this.sublabel,
    this.badge,
  });

  final int id;
  final String label;

  /// A second line — an address, or how far away a city is.
  final String? sublabel;

  /// A short tag on the right, e.g. "Nearest".
  final String? badge;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return label.toLowerCase().contains(needle) ||
        (sublabel ?? '').toLowerCase().contains(needle);
  }
}

/// A full screen that does one thing: choose one of these, with a search box.
///
/// Its own screen rather than a list inside the form because these lists grow
/// — a country's worth of cities does not fit in a row of chips, and a partner
/// should be able to type three letters instead of scrolling.
///
/// Pops with the chosen id, or null if they back out.
class SearchablePickerScreen extends ConsumerStatefulWidget {
  const SearchablePickerScreen({
    super.key,
    required this.title,
    required this.searchHint,
    required this.options,
    required this.emptyText,
    this.selectedId,
  });

  final String title;
  final String searchHint;
  final List<PickerOption> options;
  final String emptyText;
  final int? selectedId;

  @override
  ConsumerState<SearchablePickerScreen> createState() =>
      _SearchablePickerScreenState();
}

class _SearchablePickerScreenState
    extends ConsumerState<SearchablePickerScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text;
    final matches = widget.options.where((o) => o.matches(query)).toList();

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(
        backgroundColor: XpertColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.title,
          style: XpertTypography.title.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                XpertSpacing.lg,
                0,
                XpertSpacing.lg,
                XpertSpacing.md,
              ),
              child: TextField(
                controller: _controller,
                autofocus: widget.options.length > 8,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        ),
                  filled: true,
                  fillColor: XpertColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: XpertSpacing.md,
                    vertical: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(XpertRadius.lg),
                    borderSide: BorderSide(
                      color: XpertColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(XpertRadius.lg),
                    borderSide: BorderSide(
                      color: XpertColors.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(XpertSpacing.xl),
                      child: Text(
                        query.trim().isEmpty
                            ? widget.emptyText
                            : ref.t('picker.no_matches', {'query': query.trim()}),
                        textAlign: TextAlign.center,
                        style: XpertTypography.caption.copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        XpertSpacing.lg,
                        0,
                        XpertSpacing.lg,
                        XpertSpacing.xxl,
                      ),
                      itemCount: matches.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: XpertSpacing.sm),
                      itemBuilder: (context, index) => _OptionTile(
                        option: matches[index],
                        selected: matches[index].id == widget.selectedId,
                        onTap: () =>
                            Navigator.of(context).pop(matches[index].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final PickerOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? XpertColors.secondary : XpertColors.surface,
      borderRadius: BorderRadius.circular(XpertRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XpertRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(XpertSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(XpertRadius.lg),
            border: Border.all(
              color: selected
                  ? XpertColors.heroAccent
                  : XpertColors.border.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.label,
                      style: XpertTypography.label.copyWith(fontSize: 15),
                    ),
                    if (option.sublabel case final sub?) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: XpertTypography.caption.copyWith(fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (option.badge case final badge?) ...[
                const SizedBox(width: XpertSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: XpertSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: XpertColors.secondary,
                    borderRadius: BorderRadius.circular(XpertRadius.pill),
                  ),
                  child: Text(
                    badge,
                    style: XpertTypography.caption.copyWith(
                      fontSize: 11.5,
                      color: XpertColors.heroAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              if (selected) ...[
                const SizedBox(width: XpertSpacing.sm),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: XpertColors.heroAccent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
