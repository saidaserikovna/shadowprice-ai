import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../models/analysis_models.dart';
import '../models/product_model.dart';
import '../services/auth_service.dart';
import '../services/price_service.dart';
import '../services/shadowprice_api_service.dart';
import 'chat_screen.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final _queryCtrl = TextEditingController();

  bool _loading = false;
  PriceAnalysis? _result;

  Future<void> _analyze() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final result = await context.read<ShadowPriceApiService>().analyze(query);
      if (!mounted) {
        return;
      }
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _trackProduct() async {
    final result = _result;
    if (result == null) {
      return;
    }
    if (result.trackedCurrentPrice <= 0 || result.trackedSourceUrl == null) {
      return;
    }

    final auth = context.read<AuthService>();
    final priceService = context.read<PriceService>();
    final messenger = ScaffoldMessenger.of(context);
    final userId = auth.currentUser?.uid;
    if (userId == null) {
      return;
    }

    final saved = await priceService.addProduct(
      Product(
        id: '',
        userId: userId,
        name: result.productName,
        url: result.trackedSourceUrl,
        currencyCode: result.preferredCurrency,
        currentPrice: result.trackedCurrentPrice,
        marketAvg: result.averagePrice,
        lowestPrice: result.lowestPrice,
        highestPrice: result.highestPrice,
        platform: result.trackedPlatform,
        category: result.cheapestOffer?.marketplace,
        imageUrl: result.imageUrl,
        status: result.recommendation,
        notifyOnDrop: true,
      ),
    );

    await priceService.addPriceHistory(
      PriceHistoryEntry(
        id: '',
        productId: saved.id,
        price: result.trackedCurrentPrice,
        platform: result.trackedPlatform,
      ),
    );

    if (!mounted) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('This product is now being tracked.')),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-Time Price Analysis',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: ShadowTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Paste a product URL or product name to compare live marketplace prices.',
                        style: TextStyle(
                          color: ShadowTheme.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Chat'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Product URL or product name',
                      prefixIcon: Icon(Icons.search,
                          color: ShadowTheme.textMuted, size: 20),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _analyze(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _analyze,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Analyze'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSupportedLinksCard(),
            if (_loading) ...[
              const SizedBox(height: 56),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Checking the source page and searching marketplaces in parallel...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ShadowTheme.textSecondary),
                ),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildOverviewCard(),
              const SizedBox(height: 16),
              _buildRecommendationCard(),
              if (_result!.hasOffers) ...[
                const SizedBox(height: 16),
                _buildPriceSpreadCard(),
                const SizedBox(height: 16),
                _buildMarketplaceChart(),
                const SizedBox(height: 16),
                _buildMarketplaceList(),
              ] else ...[
                const SizedBox(height: 16),
                _buildNoOffersCard(),
              ],
              if (_result!.failures.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildFailuresCard(),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canTrackResult ? _trackProduct : null,
                      child: const Text('Track product'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ChatScreen()),
                        );
                      },
                      child: const Text('Ask AI'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    final result = _result!;
    final source = result.sourceProduct;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: ShadowTheme.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: result.imageUrl == null
                ? const Icon(Icons.inventory_2_outlined,
                    color: ShadowTheme.textMuted, size: 34)
                : Image.network(
                    result.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_outlined,
                      color: ShadowTheme.textMuted,
                      size: 34,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.productName,
                  style: const TextStyle(
                    color: ShadowTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _pill('${result.offers.length} live offers'),
                    _pill(
                        '${result.marketplacesChecked.length} marketplaces checked'),
                    _pill('Updated ${formatDateTime(result.timestamp)}'),
                    if (source?.storeName != null)
                      _pill('Source: ${source!.storeName}'),
                    if (source?.price != null)
                      _pill(
                        'Source price: ${formatMoney(source!.price!, source.currency ?? result.preferredCurrency)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final result = _result!;
    final recommendationColor =
        result.shouldBuyNow ? ShadowTheme.success : ShadowTheme.warning;
    final recommendationLabel = result.shouldBuyNow ? 'Buy now' : 'Wait';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: recommendationColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  recommendationLabel.toUpperCase(),
                  style: TextStyle(
                    color: recommendationColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              if (result.cheapestOffer != null)
                Text(
                  'Best: ${result.cheapestOffer!.marketplace}',
                  style: const TextStyle(
                    color: ShadowTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            result.aiSummary ?? result.reasoning,
            style: const TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (result.aiSummary != null) ...[
            const SizedBox(height: 10),
            Text(
              result.reasoning,
              style: const TextStyle(
                color: ShadowTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceSpreadCard() {
    final result = _result!;
    final cheapest = result.cheapestOffer;
    final source = result.sourceProduct;
    final sourcePrice = source?.price;
    final savings = (sourcePrice != null && cheapest != null)
        ? sourcePrice - cheapest.price
        : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price spread',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Cheapest',
                  cheapest == null
                      ? 'N/A'
                      : formatMoney(cheapest.price,
                          cheapest.currency ?? result.preferredCurrency),
                  ShadowTheme.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  'Average',
                  formatMoney(result.averagePrice, result.preferredCurrency),
                  ShadowTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  'Highest',
                  formatMoney(result.highestPrice, result.preferredCurrency),
                  ShadowTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricTile(
                  'Save vs source',
                  savings == null
                      ? 'N/A'
                      : formatMoney(savings, result.preferredCurrency),
                  savings != null && savings > 0
                      ? ShadowTheme.success
                      : ShadowTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceChart() {
    final offers = _result!.offers;
    if (offers.isEmpty) {
      return const SizedBox.shrink();
    }
    final maxPrice =
        offers.map((offer) => offer.price).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marketplace comparison',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxPrice * 1.1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: ShadowTheme.border.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= offers.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            offers[index].marketplace,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ShadowTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  offers.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: offers[index].price,
                        width: 24,
                        borderRadius: BorderRadius.circular(8),
                        color: index == 0
                            ? ShadowTheme.success
                            : ShadowTheme.accent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceList() {
    final offers = _result!.offers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live marketplace offers',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...offers.asMap().entries.map((entry) {
            final index = entry.key;
            final offer = entry.value;
            final isBest = index == 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isBest
                    ? ShadowTheme.success.withValues(alpha: 0.06)
                    : ShadowTheme.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isBest
                      ? ShadowTheme.success.withValues(alpha: 0.25)
                      : ShadowTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.marketplace,
                          style: const TextStyle(
                            color: ShadowTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ShadowTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Cheapest',
                            style: TextStyle(
                              color: ShadowTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.title,
                    style: const TextStyle(
                      color: ShadowTheme.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        formatMoney(offer.price,
                            offer.currency ?? _result!.preferredCurrency),
                        style: TextStyle(
                          color: isBest
                              ? ShadowTheme.success
                              : ShadowTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Match ${(offer.similarityScore * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: ShadowTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openLink(offer.productUrl),
                        child: const Text('Open'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFailuresCard() {
    final failures = _result!.failures;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marketplaces that could not be verified',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...failures.map(
            (failure) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: ShadowTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${failure.marketplace}: ${failure.reason}',
                      style: const TextStyle(
                        color: ShadowTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOffersCard() {
    final result = _result!;
    final source = result.sourceProduct;
    final hasSourcePrice = source?.price != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'No verified matches yet',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'ShadowPrice did not find a sufficiently close live marketplace match. Try a more direct product URL or a more specific product name.',
            style: TextStyle(
              color: ShadowTheme.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (hasSourcePrice) ...[
            const SizedBox(height: 12),
            Text(
              'Current live source price: ${formatMoney(source!.price!, source.currency ?? result.preferredCurrency)}'
              '${source.storeName == null ? '' : ' on ${source.storeName}'}',
              style: const TextStyle(
                color: ShadowTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportedLinksCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShadowTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ShadowTheme.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Best links to paste',
            style: TextStyle(
              color: ShadowTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Use direct product pages only: Kaspi /shop/p/, Amazon /dp/, eBay /itm/, AliExpress /item/, Wildberries detail.aspx, Ozon /product/. If full comparison is unavailable, ShadowPrice will still try to read the live source-page price from the pasted URL.',
            style: TextStyle(
              color: ShadowTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ShadowTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ShadowTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ShadowTheme.surfaceLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ShadowTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool get _canTrackResult {
    final result = _result;
    return result != null &&
        result.trackedCurrentPrice > 0 &&
        result.trackedSourceUrl != null;
  }
}
