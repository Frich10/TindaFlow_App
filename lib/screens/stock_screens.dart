import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/common.dart';

// ───────────────────────── Stocks tab ─────────────────────────

class StocksTab extends StatefulWidget {
  const StocksTab({super.key});
  @override
  State<StocksTab> createState() => _StocksTabState();
}

class _StocksTabState extends State<StocksTab> {
  String _q = '';
  String _cat = 'All';

  Future<void> _restock(Product p) async {
    final ctrl = TextEditingController();
    final qty = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add stock', style: ts(15, w: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.name}  •  current stock ${p.stock}', style: ts(11, c: kMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digitFormatters,
            decoration: fieldDeco(hint: 'Quantity to add'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text) ?? 0),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (qty != null && qty > 0) {
      store.restock(p.id, qty);
      if (mounted) snack(context, 'Added $qty to ${p.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final list = store.products
          .where((p) => (_cat == 'All' || p.category == _cat) && p.name.toLowerCase().contains(_q.toLowerCase()))
          .toList();
      final allCategories = store.products
          .map((p) => p.category)
          .where((c) => c.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      return BluePage(
        title: 'Stocks',
        actions: [Watch((context) => HeaderIcon(Icons.notifications, badge: store.hasAlerts, onTap: () => showAlerts(context)))],
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: SearchBox(onChanged: (v) => setState(() => _q = v)),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: ChipsRow(
              options: [
                'All',
                ...allCategories,
              ],
              selected: _cat,
              onChanged: (v) => setState(() => _cat = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(Icons.inventory_2_outlined,
                    store.products.isEmpty ? 'No products yet.\nTap "Add Product" to begin.' : 'No matching products.')
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return ProductRow(
                        product: p,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: p.id))),
                        onAdd: () => _restock(p),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppButton('Add Product', color: kGreen, icon: Icons.add, height: 42, onPressed: () {
              if (!store.isPremium && store.products.length >= kFreeProductLimit) {
                showPremiumModal(context,
                    feature: 'Unlimited products',
                    detail: 'The Free plan lets you add up to $kFreeProductLimit products. Subscribe to Premium to add unlimited products.');
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductFormScreen()));
            }),
          ),
        ]),
      );
    });
  }
}

// ───────────────────────── Product details ─────────────────────────

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) {
    return Watch((context) {
      final p = store.productById(productId);
      if (p == null) {
        return const BluePage(back: true, title: 'Stock Details', child: EmptyState(Icons.inventory_2_outlined, 'This product no longer exists.'));
      }
      final prem = store.isPremium;
      final moves = store.movesFor(p.id);
      final status = p.stock <= 0
          ? ('Out of Stock', kRed, kRedTint)
          : p.stock <= kLowStock
              ? ('Low Stock', kRed, kRedTint)
              : p.stock > 30
                  ? ('High Stock', kGreen, kGreenTint)
                  : ('In Stock', kGreen, kGreenTint);
      return BluePage(
        back: true,
        title: 'Stock Details',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              ProductThumb(p, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: ts(15, w: FontWeight.w700, c: kBlue)),
                  const SizedBox(height: 4),
                  StatusChip(status.$1, color: status.$2, bg: status.$3),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _Stat('Current Stock', '${p.stock}')),
              const SizedBox(width: 10),
              Expanded(child: _Stat('Unit Price', peso(p.price, decimals: true))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Stat('Capital Cost', peso(p.cost, decimals: true), small: true)),
              const SizedBox(width: 10),
              Expanded(
                child: prem
                    ? _Stat('Profit / Unit', peso(p.price - p.cost, decimals: true), small: true)
                    : GestureDetector(
                        onTap: () => requirePremium(context, 'Estimated profit calculation'),
                        child: const _Stat('Profit / Unit', 'Premium', small: true),
                      ),
              ),
            ]),
            const SizedBox(height: 16),
            Text('Stock History', style: ts(12, w: FontWeight.w700, c: kBlue)),
            const SizedBox(height: 6),
            if (!prem)
              const LockedCard(
                  title: 'Stock history is a Premium feature',
                  message: 'Subscribe to see every stock in and sale for this product.',
                  feature: 'Product and stock management')
            else if (moves.isEmpty)
              const EmptyState(Icons.history, 'No stock movement yet.')
            else
              for (final m in moves.take(30))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    CircleIcon(m.delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        color: m.delta > 0 ? kGreen : kRed, size: 26),
                    const SizedBox(width: 12),
                    Expanded(child: Text(fmtDate(m.date), style: ts(10, w: FontWeight.w500))),
                    Text('${m.delta > 0 ? '+' : ''}${m.delta}',
                        style: ts(11, w: FontWeight.w700, c: m.delta > 0 ? kGreen : kRed)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 66,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: StatusChip(m.reason, color: m.delta > 0 ? kGreen : kRed, bg: m.delta > 0 ? kGreenTint : kRedTint),
                      ),
                    ),
                  ]),
                ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: AppButton('Edit', height: 40, onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton('Delete', color: const Color(0xFFFF3B5C), height: 40, onPressed: () async {
                  final ok = await confirmDelete(context,
                      title: 'Delete This Item?',
                      message: 'Are you sure you want to delete this item? This action cannot be undone.');
                  if (ok) {
                    store.deleteProduct(p.id);
                    if (context.mounted) {
                      snack(context, 'Product deleted');
                      Navigator.of(context).pop();
                    }
                  }
                }),
              ),
            ]),
          ],
        ),
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.small = false});
  final String label;
  final String value;
  final bool small;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: cardDeco(color: kBlueTint, r: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: ts(10, w: FontWeight.w600, c: kBlueDark)),
        const SizedBox(height: 4),
        Text(value, style: ts(small ? 14 : 20, w: FontWeight.w700, c: kBlue)),
      ]),
    );
  }
}

// ───────────────────────── Add / edit product ─────────────────────────

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Product? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _cost = TextEditingController(text: widget.product == null ? '' : _num(widget.product!.cost));
  late final _price = TextEditingController(text: widget.product == null ? '' : _num(widget.product!.price));
  late final _stock = TextEditingController(text: widget.product == null ? '' : '${widget.product!.stock}');
  final TextEditingController _customCategory = TextEditingController();
  String? _category;
  String? _photo;

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();

    _category = widget.product?.category;
    _photo = widget.product?.photo;

    if (_category != null &&
        !kProductCategories.contains(_category)) {
      _customCategory.text = _category!;
      _category = 'Others';
    }
    for (final c in [_name, _price, _stock, _customCategory]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _price.dispose();
    _stock.dispose();
    _customCategory.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final b = await pickImageBase64(context, maxWidth: 500);
    if (b != null) setState(() => _photo = b);
  }

  
void _save() {
  if (!_key.currentState!.validate()) return;

  if (_category == 'Others' &&
      _customCategory.text.trim().isEmpty) {
    snack(context, 'Please enter a new category');
    return;
  }

  final finalCategory = _category == 'Others'
      ? _customCategory.text.trim()
      : _category!;

  final cost = parseMoney(_cost.text);
  final price = parseMoney(_price.text);
  final stock = int.tryParse(_stock.text) ?? 0;
  final old = widget.product;

  final p = Product(
    id: old?.id ?? newId(),
    name: _name.text.trim(),
    category: finalCategory,
    cost: cost,
    price: price,
    stock: stock,
    photo: _photo,
  );

  if (old == null) {
    store.addProduct(p);
  } else {
    store.updateProduct(p);
  }

  snack(context, old == null ? 'Product added' : 'Product updated');
  Navigator.of(context).pop();
}

  /// Category shown in the preview (the typed one when "Others" is chosen).
  String? get _previewCategory {
    if (_category == 'Others') {
      final t = _customCategory.text.trim();
      return t.isEmpty ? 'Others' : t;
    }
    return _category;
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return BluePage(
      back: true,
      title: editing ? 'Edit Product' : 'Add Product',
      child: FormBody(
        formKey: _key,
        button: AppButton('Save', onPressed: _save),
        children: [
          // Live preview card: shows the photo, name, category, price and stock you enter.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: cardDeco(shadow: true, r: 14),
            child: Row(children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: cardDeco(color: kBlueTint, r: 10),
                  child: _photo != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(decodeImg(_photo!), fit: BoxFit.cover, gaplessPlayback: true))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.photo_camera, color: kBlue, size: 26),
                          const SizedBox(height: 4),
                          Text('Add Photo', style: ts(8.5, w: FontWeight.w600, c: kBlue)),
                        ]),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _name.text.trim().isEmpty ? 'Product name' : _name.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts(13, w: FontWeight.w700, c: _name.text.trim().isEmpty ? kMuted : kBlue),
                  ),
                  if (_previewCategory != null) ...[
                    const SizedBox(height: 2),
                    Text(_previewCategory!, style: ts(9.5, c: kMuted)),
                  ],
                  const SizedBox(height: 4),
                  Text(peso(parseMoney(_price.text), decimals: true), style: ts(18, w: FontWeight.w700, c: kBlue)),
                ]),
              ),
              const SizedBox(width: 8),
              StockChip(int.tryParse(_stock.text) ?? 0),
            ]),
          ),
          const SizedBox(height: 16),
          AppField(label: 'Product Name', controller: _name, hint: 'Product name', required: true),
          
          AppDropdown(
            label: 'Category',
            hint: 'Category',
            items: kProductCategories,
            value: _category,
            onChanged: (v) {
              setState(() {
                _category = v;
                if (v != 'Others') {
                  _customCategory.clear();
                }
              });
            },
          ),

          if (_category == 'Others') ...[
            AppField(
              label: 'New Category',
              controller: _customCategory,
              hint: 'Enter new category',
              required: true,
            ),
          ],
          AppField(label: 'Capital Cost', controller: _cost, hint: '0.00', prefixText: '₱', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: moneyFormatters, validator: (v) => moneyError(v, allowZero: true)),
          AppField(label: 'Selling Price', controller: _price, hint: '0.00', prefixText: '₱', keyboard: const TextInputType.numberWithOptions(decimal: true), formatters: moneyFormatters, validator: moneyError),
          AppField(label: 'Stock Quantity', controller: _stock, hint: '0', keyboard: TextInputType.number, formatters: digitFormatters),
        ],
      ),
    );
  }
}