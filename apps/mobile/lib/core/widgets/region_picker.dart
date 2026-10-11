import 'package:flutter/material.dart';

import '../../features/auth/domain/user.dart';
import '../../l10n/app_localizations.dart';
import '../theme/iftar_colors.dart';

/// Region form field that opens a searchable bottom sheet, so a long list of
/// regions stays usable on a phone. With [allLabel], the sheet starts with an
/// "all regions" entry whose value is null.
class RegionPickerField extends FormField<int?> {
  RegionPickerField({
    super.key,
    required List<Region> regions,
    required int? value,
    required ValueChanged<int?> onChanged,
    String? hint,
    String? allLabel,
    InputDecoration decoration = const InputDecoration(),
    super.validator,
    bool enabled = true,
  }) : super(
         initialValue: value,
         enabled: enabled && (regions.isNotEmpty || allLabel != null),
         builder: (field) {
           final selected = regions
               .where((r) => r.id == field.value)
               .firstOrNull;
           final label =
               selected?.name ?? (field.value == null ? allLabel : null);
           final context = field.context;
           return InkWell(
             borderRadius: BorderRadius.circular(12),
             onTap: field.widget.enabled
                 ? () async {
                     final picked = await showRegionSearchSheet(
                       context,
                       regions: regions,
                       selectedId: field.value,
                       allLabel: allLabel,
                     );
                     if (picked == null) return;
                     field.didChange(picked.id);
                     onChanged(picked.id);
                   }
                 : null,
             child: InputDecorator(
               isEmpty: label == null,
               decoration: decoration.copyWith(
                 hintText: hint,
                 errorText: field.errorText,
                 enabled: field.widget.enabled,
                 suffixIcon:
                     decoration.suffixIcon ??
                     const Icon(Icons.arrow_drop_down_rounded),
               ),
               child: label == null
                   ? null
                   : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
             ),
           );
         },
       );

  @override
  FormFieldState<int?> createState() => _RegionPickerFieldState();
}

class _RegionPickerFieldState extends FormFieldState<int?> {
  @override
  void didUpdateWidget(FormField<int?> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Follow the parent's value when it changes from outside the sheet.
    if (widget.initialValue != oldWidget.initialValue) {
      setValue(widget.initialValue);
    }
  }
}

/// Searchable region list. Returns null when dismissed, otherwise the picked
/// id (null id = [allLabel] entry).
Future<({int? id})?> showRegionSearchSheet(
  BuildContext context, {
  required List<Region> regions,
  int? selectedId,
  String? allLabel,
}) => showModalBottomSheet<({int? id})>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _RegionSearchSheet(
    regions: regions,
    selectedId: selectedId,
    allLabel: allLabel,
  ),
);

class _RegionSearchSheet extends StatefulWidget {
  const _RegionSearchSheet({
    required this.regions,
    required this.selectedId,
    required this.allLabel,
  });

  final List<Region> regions;
  final int? selectedId;
  final String? allLabel;

  @override
  State<_RegionSearchSheet> createState() => _RegionSearchSheetState();
}

class _RegionSearchSheetState extends State<_RegionSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final q = searchKey(_query);
    final matches = widget.regions
        .where((r) => searchKey(r.name).contains(q))
        .toList();
    final showAll = widget.allLabel != null && q.isEmpty;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: widget.regions.length > 8,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l.searchRegions,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(
              child: matches.isEmpty && !showAll
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        l.noRegionFound,
                        style: TextStyle(color: context.colors.inkMuted),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        if (showAll)
                          ListTile(
                            title: Text(widget.allLabel!),
                            selected: widget.selectedId == null,
                            onTap: () => Navigator.pop(context, (id: null)),
                          ),
                        for (final r in matches)
                          ListTile(
                            title: Text(r.name),
                            selected: r.id == widget.selectedId,
                            onTap: () => Navigator.pop(context, (id: r.id)),
                          ),
                      ],
                    ),
            ),
            SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Lower-case, without Latin accents or Arabic vowel marks, so "sokra"
/// finds "Dar Sokra" and "صكرة" finds "صُكْرة".
String searchKey(String text) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ÿ': 'y',
  };
  final out = StringBuffer();
  for (final ch in text.trim().toLowerCase().split('')) {
    final code = ch.codeUnitAt(0);
    if (code >= 0x064B && code <= 0x0652) continue; // tashkeel
    if (code == 0x0640) continue; // tatweel
    out.write(accents[ch] ?? ch);
  }
  return out.toString();
}
