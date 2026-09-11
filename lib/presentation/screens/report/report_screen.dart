import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../providers/sales_provider.dart';
import '../../providers/distributor_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../widgets/kpi_card.dart';
import '../../widgets/sales_graph_widget.dart';
import '../../widgets/app_drawer.dart';
import '../../providers/book_provider.dart';
import '../../widgets/inventory_widgets.dart';
import 'item_sales_summary_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadSales();
      context.read<SalesProvider>().loadSalesReturns();
      context.read<DistributorProvider>().loadDistributors();
      context.read<CustomerProvider>().loadCustomers();
      context.read<PurchaseProvider>().loadPurchases();
      context.read<PurchaseProvider>().loadPurchaseReturns();
      context.read<BookProvider>().loadBooks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final salesProvider = context.watch<SalesProvider>();
    final distributorProvider = context.watch<DistributorProvider>();
    final customerProvider = context.watch<CustomerProvider>();
    final purchaseProvider = context.watch<PurchaseProvider>();

    // Calculate KPIs
    final today = DateTime.now();

    // Sales Logic
    final todaySales = salesProvider.sales.where((sale) {
      final saleDate = DateTime.parse(sale.timestamp);
      return saleDate.year == today.year &&
          saleDate.month == today.month &&
          saleDate.day == today.day;
    }).toList();

    final todaySalesReturns = salesProvider.salesReturns.where((ret) {
      final retDate = DateTime.parse(ret.timestamp);
      return retDate.year == today.year &&
          retDate.month == today.month &&
          retDate.day == today.day;
    }).toList();

    final todayRevenue =
        todaySales.fold(0.0, (sum, sale) => sum + sale.totalAmount);
    final todayRefunds =
        todaySalesReturns.fold(0.0, (sum, ret) => sum + ret.totalRefund);

    final netSales = todayRevenue - todayRefunds;
    final totalTransactions = todaySales.length + todaySalesReturns.length;

    // Payment Method Breakdown
    final cashSales = todaySales
        .where((s) => s.paymentMethod == 'Cash')
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    final cardSales = todaySales
        .where((s) => s.paymentMethod == 'Card')
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    final upiSales = todaySales
        .where((s) => s.paymentMethod == 'UPI')
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    final creditSales = todaySales
        .where((s) => s.paymentMethod == 'Credit')
        .fold(0.0, (sum, s) => sum + s.totalAmount);

    // Purchase Logic
    final todayPurchases = purchaseProvider.purchases.where((purchase) {
      final pDate = DateTime.parse(purchase.timestamp);
      return pDate.year == today.year &&
          pDate.month == today.month &&
          pDate.day == today.day;
    }).toList();

    final todayPurchaseTotal = todayPurchases.fold(
        0.0,
        (sum, p) =>
            sum + p.totalAmount); // Assuming totalAmount is what user wants

    final todayPurchaseReturns = purchaseProvider.purchaseReturns.where((ret) {
      final rDate = DateTime.parse(ret.timestamp);
      return rDate.year == today.year &&
          rDate.month == today.month &&
          rDate.day == today.day;
    }).toList();

    final purchaseTransactions =
        todayPurchases.length + todayPurchaseReturns.length;

    // Calculate Balances
    final totalToPay =
        distributorProvider.distributors.fold(0.0, (sum, d) => sum + d.balance);
    final totalToReceive =
        customerProvider.customers.fold(0.0, (sum, c) => sum + c.balance);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<SalesProvider>().loadSales();
          await context.read<SalesProvider>().loadSalesReturns();
          await context.read<DistributorProvider>().loadDistributors();
          await context.read<CustomerProvider>().loadCustomers();
          await context.read<PurchaseProvider>().loadPurchases();
          await context.read<PurchaseProvider>().loadPurchaseReturns();
          await context.read<BookProvider>().loadBooks();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Section
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.5 : 1.2,
                    children: [
                      KpiCard(
                        title: 'Total Sales',
                        value: '₹${netSales.toStringAsFixed(2)}',
                        icon: Icons.payments,
                        color: AppTheme.accent500,
                      ),
                      KpiCard(
                        title: 'Sales Txns',
                        value: '$totalTransactions',
                        icon: Icons.receipt_long,
                        color: AppTheme.warningText,
                      ),
                      KpiCard(
                        title: 'Total Purchase',
                        value: '₹${todayPurchaseTotal.toStringAsFixed(2)}',
                        icon: Icons.shopping_cart,
                        color: Colors.purple, // Distinct color
                      ),
                      KpiCard(
                        title: 'Purchase Txns',
                        value: '$purchaseTransactions',
                        icon: Icons.receipt,
                        color: Colors.teal, // Distinct color
                      ),
                      KpiCard(
                        title: 'To Receive',
                        value: '₹${totalToReceive.toStringAsFixed(2)}',
                        icon: Icons.arrow_circle_down,
                        color: AppTheme.successText,
                      ),
                      KpiCard(
                        title: 'To Pay',
                        value: '₹${totalToPay.toStringAsFixed(2)}',
                        icon: Icons.arrow_circle_up,
                        color: AppTheme.errorText,
                      ),
                    ],
                  );
                },
              ),
              // KPI Section
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.accent300),
                ),
                color: AppTheme.accent50,
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2, color: Colors.white),
                  ),
                  title: const Text(
                    'Item Sales Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.neutral900,
                    ),
                  ),
                  subtitle: const Text(
                    'View consolidated copies sold by date range (Excludes Credit & Complementary)',
                    style: TextStyle(fontSize: 12, color: AppTheme.neutral600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: AppTheme.accent700),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ItemSalesSummaryScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sales By Payment',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return GridView.count(
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: isWide ? 1.5 : 1.2,
                    children: [
                      // Payment Method Breakdown Cards
                      KpiCard(
                        title: 'Cash Sales',
                        value: '₹${cashSales.toStringAsFixed(2)}',
                        icon: Icons.attach_money,
                        color: Colors.green,
                      ),
                      KpiCard(
                        title: 'Card Sales',
                        value: '₹${cardSales.toStringAsFixed(2)}',
                        icon: Icons.credit_card,
                        color: Colors.blue,
                      ),
                      KpiCard(
                        title: 'UPI Sales',
                        value: '₹${upiSales.toStringAsFixed(2)}',
                        icon: Icons.qr_code,
                        color: Colors.orange,
                      ),
                      KpiCard(
                        title: 'Credit Sales',
                        value: '₹${creditSales.toStringAsFixed(2)}',
                        icon: Icons.history_edu,
                        color: Colors.purple,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              // Inventory Intelligence Section
              Text(
                'Sales Trend (Last 7 Days)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              // Sales Trend Graph
              Container(
                height: 300,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neutral200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: SalesGraphWidget(sales: salesProvider.sales)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Inventory Intelligence Section
              Text(
                'Inventory Intelligence',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              const LowStockBooksWidget(),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  if (isWide) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: TopSellingBooksWidget()),
                        SizedBox(width: 16),
                        Expanded(child: DeadStockBooksWidget()),
                      ],
                    );
                  } else {
                    return const Column(
                      children: [
                        TopSellingBooksWidget(),
                        SizedBox(height: 16),
                        DeadStockBooksWidget(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
