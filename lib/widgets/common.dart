import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/subscription_service.dart';
import '../screens/subscription_screens.dart';

// ───────────────────────── helpers ─────────────────────────

/// Rebuilds whenever the global [store] changes.
class Watch extends StatelessWidget {
  const Watch(this.builder, {super.key});
  final Widget Function(BuildContext context) builder;
  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: store, builder: (c, _) => builder(c));
}

void snack(BuildContext context, String msg) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(milliseconds: 1800),
  ));
}

final Map<String, Uint8List> _imgCache = {};
Uint8List decodeImg(String b64) => _imgCache.putIfAbsent(b64, () => base64Decode(b64));

Future<String?> pickImageBase64(BuildContext context, {double maxWidth = 600}) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Take a photo'),
          onTap: () => Navigator.pop(c, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.pop(c, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (src == null) return null;
  try {
    final x = await ImagePicker().pickImage(source: src, maxWidth: maxWidth, imageQuality: 75);
    if (x == null) return null;
    return base64Encode(await x.readAsBytes());
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Unable to open the ${src == ImageSource.camera ? 'camera' : 'gallery'} on this device.');
    }
    return null;
  }
}

Future<DateTime?> pickDate(BuildContext c, DateTime? initial) => showDatePicker(
      context: c,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

Future<TimeOfDay?> pickTime(BuildContext c, TimeOfDay? initial) =>
    showTimePicker(context: c, initialTime: initial ?? TimeOfDay.now());

String fmtTimeOfDay(TimeOfDay t) =>
    fmtTime(DateTime(2000, 1, 1, t.hour, t.minute));

DateTime combine(DateTime d, TimeOfDay t) => DateTime(d.year, d.month, d.day, t.hour, t.minute);

String? passwordError(String? v) {
  if (v == null || v.isEmpty) return 'Required';
  if (v.length < 8) return 'At least 8 characters';
  if (!RegExp(r'[0-9]').hasMatch(v)) return 'Include a number';
  if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Include a capital letter';
  return null;
}

String? emailError(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
  return null;
}

String? phoneError(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  if (v.replaceAll(RegExp(r'\D'), '').length < 7) return 'Enter a valid phone number';
  return null;
}

String? moneyError(String? v, {bool allowZero = false}) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final n = double.tryParse(v.replaceAll(',', ''));
  if (n == null) return 'Enter a valid amount';
  if (n < 0 || (!allowZero && n == 0)) return 'Must be greater than 0';
  return null;
}

final List<TextInputFormatter> moneyFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
final List<TextInputFormatter> digitFormatters = [FilteringTextInputFormatter.digitsOnly];

// ───────────────────────── page scaffold ─────────────────────────

/// Blue header + rounded light body, used by every screen.
class BluePage extends StatelessWidget {
  const BluePage({
    super.key,
    this.title,
    this.header,
    this.back = false,
    this.actions = const [],
    required this.child,
    this.fab,
    this.onBack,
    this.bodyColor = kBg,
  });
  final String? title;
  final Widget? header;
  final bool back;
  final List<Widget> actions;
  final Widget child;
  final Widget? fab;
  final VoidCallback? onBack;
  final Color bodyColor;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kBlue,
        floatingActionButton: fab,
        body: Column(children: [
          SafeArea(bottom: false, child: header ?? _bar(context)),
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: bodyColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: child,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _bar(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Stack(alignment: Alignment.center, children: [
          if (back)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: onBack ?? () => Navigator.maybePop(context),
              ),
            ),
          if (title != null) Text(title!, style: ts(16, w: FontWeight.w600, c: Colors.white)),
          Align(
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ]),
      ),
    );
  }
}

class HeaderIcon extends StatelessWidget {
  const HeaderIcon(this.icon, {super.key, this.onTap, this.badge = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool badge;
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Stack(clipBehavior: Clip.none, children: [
        Icon(icon, color: Colors.white, size: 22),
        if (badge)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
            ),
          ),
      ]),
    );
  }
}

// ───────────────────────── buttons ─────────────────────────

class AppButton extends StatelessWidget {
  const AppButton(
    this.text, {
    super.key,
    this.onPressed,
    this.color = kBlue,
    this.outlined = false,
    this.icon,
    this.height = 44,
    this.leading,
  });
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final bool outlined;
  final IconData? icon;
  final Widget? leading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final label = Row(mainAxisSize: MainAxisSize.min, children: [
      if (leading != null) ...[leading!, const SizedBox(width: 8)],
      if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
      Flexible(child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
    ]);
    final size = Size.fromHeight(height);
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          foregroundColor: color,
          side: BorderSide(color: onPressed == null ? Colors.grey.shade300 : color),
          shape: const StadiumBorder(),
        ),
        child: label,
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: size,
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFDADDE2),
        disabledForegroundColor: const Color(0xFFA6ABB3),
        shape: const StadiumBorder(),
      ),
      child: label,
    );
  }
}

class CircleAdd extends StatelessWidget {
  const CircleAdd({super.key, this.onTap, this.size = 28, this.color = kGreen, this.icon = Icons.add});
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: onTap == null ? Colors.grey.shade400 : color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.64),
      ),
    );
  }
}

// ───────────────────────── inputs ─────────────────────────

InputDecoration fieldDeco({String? hint, IconData? icon, String? prefixText, Widget? suffix}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: kFieldBorder, width: 1),
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    hintText: hint,
    hintStyle: ts(11, c: const Color(0xFFB4BFCF)),
    prefixIcon: icon != null
        ? Icon(icon, size: 18, color: kText)
        : (prefixText != null
            ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(prefixText, style: ts(13, w: FontWeight.w600)),
              )
            : null),
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: border,
    enabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: kBlue, width: 1.6),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: kRed, width: 1),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: kRed, width: 1.6),
    ),
    errorStyle: ts(10, c: kRed),
  );
}

Widget fieldLabel(String label, bool required) => Text.rich(
      TextSpan(
        text: label,
        style: ts(11, w: FontWeight.w600, c: kBlueDark),
        children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: kRed))],
      ),
    );

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.icon,
    this.prefixText,
    this.keyboard,
    this.required = true,
    this.readOnly = false,
    this.onTap,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.maxLines = 1,
    this.formatters,
    this.onChanged,
    this.showLabel = true,
    this.bottomGap = 12,
  });
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? icon;
  final String? prefixText;
  final TextInputType? keyboard;
  final bool required;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final int maxLines;
  final List<TextInputFormatter>? formatters;
  final ValueChanged<String>? onChanged;
  final bool showLabel;
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showLabel) ...[fieldLabel(label, required), const SizedBox(height: 6)],
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        readOnly: readOnly,
        onTap: onTap,
        obscureText: obscure,
        maxLines: obscure ? 1 : maxLines,
        inputFormatters: formatters,
        onChanged: onChanged,
        style: ts(12),
        validator: validator ??
            (required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null),
        decoration: fieldDeco(hint: hint, icon: icon, prefixText: prefixText, suffix: suffix),
      ),
      SizedBox(height: bottomGap),
    ]);
  }
}

class AppDropdown extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.hint = 'Select',
    this.required = true,
  });
  final String label;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String? value;
  final String hint;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      fieldLabel(label, required),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : null,
        isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down, color: kBlue),
        decoration: fieldDeco(),
        hint: Text(hint, style: ts(11, c: const Color(0xFFB4BFCF))),
        items: [
          for (final i in items) DropdownMenuItem<String>(value: i, child: Text(i, style: ts(12))),
        ],
        onChanged: onChanged,
        validator: required ? (v) => v == null ? 'Required' : null : null,
      ),
      const SizedBox(height: 12),
    ]);
  }
}


class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.onChanged,
    this.hint = 'Search product...',
  });

  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: cardDeco(
        r: 22,
        border: const Color(0xFFD5E4F7),
      ),
      child: TextField(
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: ts(12),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: ts(11, c: const Color(0xFFB4BFCF)),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: kMuted,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 40,
          ),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

// ───────────────────────── chips / tabs ─────────────────────────

class SegmentTabs extends StatelessWidget {
  const SegmentTabs({super.key, required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < options.length; i++)
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected ? kBlue : const Color(0xFFDDF5EA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(options[i],
                    style: ts(11, w: FontWeight.w600, c: i == selected ? Colors.white : kBlue)),
              ),
            ),
          ),
        ),
    ]);
  }
}

class ChipsRow extends StatelessWidget {
  const ChipsRow({super.key, required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = options[i] == selected;
          return GestureDetector(
            onTap: () => onChanged(options[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? kBlue : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: sel ? kBlue : const Color(0xFFD5E4F7)),
                boxShadow: sel
                    ? null
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Text(options[i], style: ts(11, w: FontWeight.w600, c: sel ? Colors.white : kText)),
            ),
          );
        },
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.color = kGreen, this.bg = kGreenTint});
  final String text;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: ts(9, w: FontWeight.w600, c: color)),
    );
  }
}

// ───────────────────────── visual bits ─────────────────────────

class GIcon extends StatelessWidget {
  const GIcon({super.key, this.size = 30, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: light ? Colors.white : kBlue, shape: BoxShape.circle),
      child: Text('G',
          style: TextStyle(
              fontSize: size * 0.55, fontWeight: FontWeight.w800, color: light ? kBlue : Colors.white)),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon(this.icon, {super.key, this.color = kBlue, this.size = 34, this.solid = true});
  final IconData icon;
  final Color color;
  final double size;
  final bool solid;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: solid ? color : color.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: solid ? Colors.white : color, size: size * 0.55),
    );
  }
}

class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.name, {super.key, this.size = 36, this.photo});
  final String name;
  final double size;
  final String? photo;
  @override
  Widget build(BuildContext context) {
    const palette = [kBlue, kGreen, kOrange, kPurple, kRed, Color(0xFF0EA5A4)];
    final color = palette[name.codeUnits.fold(0, (a, b) => a + b) % palette.length];
    if (photo != null) {
      return ClipOval(child: Image.memory(decodeImg(photo!), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true));
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
      child: Text(initials(name), style: ts(size * 0.34, w: FontWeight.w700, c: color)),
    );
  }
}

const _catIcons = <String, IconData>{
  'Drinks': Icons.local_drink,
  'Coffee': Icons.coffee,
  'Chips': Icons.fastfood,
  'Candy': Icons.cake,
  'Noodles': Icons.ramen_dining,
  'Snacks': Icons.cookie,
  'Canned Goods': Icons.inventory_2,
  'Others': Icons.shopping_bag,
};
const _catColors = <String, Color>{
  'Drinks': kRed,
  'Coffee': Color(0xFF8D5A2B),
  'Chips': kOrange,
  'Candy': Color(0xFFEC4899),
  'Noodles': Color(0xFFEAB308),
  'Snacks': kBlue,
  'Canned Goods': kGreen,
  'Others': kPurple,
};

class ProductThumb extends StatelessWidget {
  const ProductThumb(this.product, {super.key, this.size = 40});
  final Product? product;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p != null && p.photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(decodeImg(p.photo!), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
      );
    }
    final cat = p?.category ?? 'Others';
    final c = _catColors[cat] ?? kBlue;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(8)),
      child: Icon(_catIcons[cat] ?? Icons.shopping_bag, color: c, size: size * 0.55),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: kMuted.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(text, textAlign: TextAlign.center, style: ts(12, c: kMuted)),
        ]),
      ),
    );
  }
}

class StockChip extends StatelessWidget {
  const StockChip(this.stock, {super.key});
  final int stock;
  @override
  Widget build(BuildContext context) {
    final low = stock <= kLowStock;
    return StatusChip('Stock: $stock', color: low ? kRed : kGreen, bg: low ? kRedTint : kGreenTint);
  }
}

class ProductRow extends StatelessWidget {
  const ProductRow({super.key, required this.product, this.onTap, this.onAdd});
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE3ECF7)))),
        child: Row(children: [
          ProductThumb(product, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: ts(12, w: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(peso(product.price, decimals: true), style: ts(12, w: FontWeight.w700, c: kBlue)),
            ]),
          ),
          StockChip(product.stock),
          const SizedBox(width: 10),
          CircleAdd(onTap: onAdd),
        ]),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.icon, this.label, this.value, {super.key, this.last = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFE3ECF7))),
      ),
      child: Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: kBlueTint, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: kBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: ts(9, c: kMuted)),
            Text(value, style: ts(11, w: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class ActivityTile extends StatelessWidget {
  const ActivityTile(this.a, {super.key});
  final Activity a;

  @override
  Widget build(BuildContext context) {
    final c = a.positive ? kGreen : kRed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        if (a.title.startsWith('Cash'))
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFF1468F5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                'assets/images/gcash_logo.png',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
            ),
          )
        else if (a.title == 'Expense')
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFFF891B),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/expense_icon.png',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            ),
          )
        else
          CircleIcon(a.icon, color: a.color, size: 30),

        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title, style: ts(11, w: FontWeight.w700, c: kBlue)),
              Text(a.subtitle, style: ts(8.5, c: kMuted)),
            ],
          ),
        ),
        Text(
          '${a.positive ? '+' : '-'} ${peso(a.amount)}',
          style: ts(12, w: FontWeight.w700, c: c),
        ),
      ]),
    );
  }
}

// ───────────────────────── dialogs ─────────────────────────

Future<bool> confirmDelete(
  BuildContext context, {
  String title = 'Delete Transaction?',
  String message = 'Are you sure you want to delete this transaction? This action cannot be undone.',
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle),
            child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title, style: ts(13, w: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: ts(10, c: kMuted), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          AppButton('Delete', color: kRed, height: 38, onPressed: () => Navigator.pop(c, true)),
          const SizedBox(height: 8),
          AppButton('Cancel', height: 38, onPressed: () => Navigator.pop(c, false)),
        ]),
      ),
    ),
  );
  return r ?? false;
}

void showAlerts(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (c) {
      final low = store.lowStockProducts;
      final due = store.dueDebts;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(18),
            children: [
              Text('Notifications', style: ts(15, w: FontWeight.w700)),
              const SizedBox(height: 12),
              if (low.isEmpty && due.isEmpty) const EmptyState(Icons.notifications_none, "You're all caught up!"),
              if (low.isNotEmpty) ...[
                Text('Low stock', style: ts(12, w: FontWeight.w600, c: kRed)),
                for (final p in low)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: ProductThumb(p, size: 34),
                    title: Text(p.name, style: ts(12, w: FontWeight.w600)),
                    trailing: StockChip(p.stock),
                  ),
                const SizedBox(height: 8),
              ],
              if (due.isNotEmpty) ...[
                Text('Debts due soon', style: ts(12, w: FontWeight.w600, c: kOrange)),
                for (final d in due)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: InitialAvatar(d.customer, size: 34),
                    title: Text(d.customer, style: ts(12, w: FontWeight.w600)),
                    subtitle: Text('Due ${fmtDate(d.dueDate)}', style: ts(10, c: kMuted)),
                    trailing: Text(peso(d.total), style: ts(12, w: FontWeight.w700, c: kRed)),
                  ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Pale wrapper around form pages: padded, scrollable, safe from keyboard.
class FormBody extends StatelessWidget {
  const FormBody({super.key, required this.formKey, required this.children, this.button});
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final Widget? button;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
        ),
      ),
      if (button != null)
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 14), child: button)),
    ]);
  }
}

// ───────────────────────── Premium gate ─────────────────────────

void _openSubscription(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
}

/// "You need to subscribe first" modal. The Subscribe button opens the Subscription screen.
Future<void> showPremiumModal(BuildContext context, {required String feature, String? detail}) {
  return showDialog<void>(
    context: context,
    builder: (c) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle),
            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          Text('Premium Feature', style: ts(15, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 8),
          Text(
            detail ?? '$feature is only available on the Premium Plan. You need to subscribe first to access this.',
            textAlign: TextAlign.center,
            style: ts(10.5, h: 1.6),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: kGreenTint, borderRadius: BorderRadius.circular(8)),
            child: Text('Premium • ₱39 / month', style: ts(10, w: FontWeight.w700, c: kGreen)),
          ),
          const SizedBox(height: 16),
          AppButton('Subscribe', height: 40, icon: Icons.workspace_premium, onPressed: () {
            Navigator.pop(c);
            _openSubscription(context);
          }),
          const SizedBox(height: 8),
          AppButton('Not now', outlined: true, height: 40, onPressed: () => Navigator.pop(c)),
        ]),
      ),
    ),
  );
}

/// Returns true when the user is on Premium. Otherwise shows the subscribe modal and returns false.
bool requirePremium(BuildContext context, String feature, {String? detail}) {
  subscription.checkExpiry(); // drops back to Free right away if the paid month has ended
  if (store.isPremium) return true;
  showPremiumModal(context, feature: feature, detail: detail);
  return false;
}

/// Full-page placeholder for a Premium-only screen.
class PremiumLockedView extends StatelessWidget {
  const PremiumLockedView({super.key, required this.feature, required this.description});
  final String feature;
  final String description;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: kBlueTint, shape: BoxShape.circle),
            child: const Icon(Icons.lock_outline, color: kBlue, size: 32),
          ),
          const SizedBox(height: 14),
          Text(feature, textAlign: TextAlign.center, style: ts(15, w: FontWeight.w700, c: kBlue)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center, style: ts(10.5, c: kMuted, h: 1.6)),
          const SizedBox(height: 18),
          SizedBox(
            width: 200,
            child: AppButton('Subscribe', height: 40, icon: Icons.workspace_premium, onPressed: () => _openSubscription(context)),
          ),
        ]),
      ),
    );
  }
}

/// Small tappable card shown in place of a Premium-only section.
class LockedCard extends StatelessWidget {
  const LockedCard({super.key, required this.title, required this.message, required this.feature});
  final String title;
  final String message;
  final String feature;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => requirePremium(context, feature),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardDeco(color: kBlueTint, border: kBlue.withValues(alpha: 0.25), r: 10),
        child: Row(children: [
          const Icon(Icons.lock_outline, color: kBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(11, w: FontWeight.w700, c: kBlue)),
              Text(message, style: ts(9.5, c: kBlueDark, h: 1.4)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: kBlue, size: 18),
        ]),
      ),
    );
  }
}