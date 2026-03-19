import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/price_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final priceService = context.read<PriceService>();
    final userId = auth.currentUser?.uid;

    if (userId == null) return const SizedBox();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: FutureBuilder<Map<String, dynamic>?>(
                future: auth.getUserProfile(),
                builder: (ctx, snap) {
                  final name = snap.data?['name'] ?? 'User';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hello, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: ShadowTheme.textPrimary)),
                      const SizedBox(height: 4),
                      const Text('Verified price tracking for your saved products', style: TextStyle(color: ShadowTheme.textSecondary, fontSize: 13)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search, color: ShadowTheme.textMuted, size: 20),
                  filled: true,
                  fillColor: ShadowTheme.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Products list
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: priceService.getUserProducts(userId),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final products = (snap.data ?? []).where((p) =>
                    p.name.toLowerCase().contains(_search.toLowerCase()) ||
                    (p.platform ?? '').toLowerCase().contains(_search.toLowerCase())
                  ).toList();

                  if (products.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 48, color: ShadowTheme.textMuted),
                          const SizedBox(height: 12),
                          const Text('No tracked products yet', style: TextStyle(color: ShadowTheme.textSecondary, fontSize: 15)),
                          const SizedBox(height: 4),
                          const Text('Run a verified check from the Analyze tab', style: TextStyle(color: ShadowTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  final overpaying = products.where((p) => p.isOverpaying).length;
                  final buyNow = products.where((p) => p.status == 'buy').length;

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      Row(
                        children: [
                          _StatCard('Tracking', '${products.length}', ShadowTheme.accent),
                          const SizedBox(width: 8),
                          _StatCard('Above avg', '$overpaying', ShadowTheme.danger),
                          const SizedBox(width: 8),
                          _StatCard('Buy now', '$buyNow', ShadowTheme.success),
                        ],
                      ),
                      const SizedBox(height: 16),

                      ...products.map((p) => _ProductCard(
                        product: p,
                        onDelete: () => priceService.deleteProduct(p.id),
                        onToggleNotify: () => priceService.toggleNotify(p.id, p.notifyOnDrop),
                      )),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ShadowTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ShadowTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: ShadowTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onDelete;
  final VoidCallback onToggleNotify;

  const _ProductCard({required this.product, required this.onDelete, required this.onToggleNotify});

  @override
  Widget build(BuildContext context) {
    final op = product.overpayPercent;
    final isOver = product.isOverpaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, color: ShadowTheme.textPrimary, fontSize: 14), overflow: TextOverflow.ellipsis),
                    ),
                    if (product.platform != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: ShadowTheme.surfaceLight, borderRadius: BorderRadius.circular(6)),
                        child: Text(product.platform!, style: const TextStyle(color: ShadowTheme.textMuted, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(formatMoney(product.currentPrice, product.currencyCode),
                      style: TextStyle(color: ShadowTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13, fontFeatures: const [FontFeature.tabularFigures()])),
                    const SizedBox(width: 12),
                    Text('Avg: ${formatMoney(product.marketAvg, product.currencyCode)}',
                      style: const TextStyle(color: ShadowTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // Overpay %
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOver ? ShadowTheme.danger.withValues(alpha: 0.1) : ShadowTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isOver ? Icons.trending_up : Icons.trending_down, size: 14, color: isOver ? ShadowTheme.danger : ShadowTheme.success),
                const SizedBox(width: 4),
                Text('${op.abs().toStringAsFixed(1)}%',
                  style: TextStyle(color: isOver ? ShadowTheme.danger : ShadowTheme.success, fontWeight: FontWeight.w700, fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ),

          const SizedBox(width: 4),
          IconButton(
            icon: Icon(product.notifyOnDrop ? Icons.notifications_active : Icons.notifications_off_outlined,
              size: 18, color: product.notifyOnDrop ? ShadowTheme.accent : ShadowTheme.textMuted),
            onPressed: onToggleNotify,
            splashRadius: 18,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: ShadowTheme.textMuted),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ShadowTheme.surface,
                  title: const Text('Delete product?'),
                  content: Text('${product.name} will be removed from tracking.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () { onDelete(); Navigator.pop(ctx); },
                      child: const Text('Delete', style: TextStyle(color: ShadowTheme.danger)),
                    ),
                  ],
                ),
              );
            },
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}
