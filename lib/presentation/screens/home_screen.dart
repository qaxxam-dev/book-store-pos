import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../providers/sales_provider.dart';
import '../providers/book_provider.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/app_drawer.dart';
import '../providers/distributor_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/settings/settings_screen.dart';
import 'sales/sales_entry_screen.dart';
import '../screens/inventory/book_list_screen.dart';
import '../screens/sales_return/sales_return_entry_screen.dart';
import '../screens/inventory/add_edit_book_screen.dart';
import '../screens/customer/customer_list_screen.dart';
import '../screens/distributor/distributor_list_screen.dart';
import '../screens/purchase/purchase_entry_screen.dart';
import 'purchase_return/purchase_return_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesProvider>().loadSales();
      // context.read<BookProvider>().loadBooks(); // Kept if needed for lookup, but maybe not if strictly following removing inventory intelligence.
      // Actually BookProvider is partly used for Book Lookup -> BookListScreen likely uses it internally or reloads.
      // Wait, BookListScreen is pushed from Quick Actions. It will load books when it inits.
      // But HomeScreen calls it in line 35. Let's keep it if Book Lookup relies on it being preloaded?
      // Actually the prompt says "Inventory Intelligence" logic.
      // The instruction was: "remove unused import `inventory_widgets.dart`" and "Remove 'Inventory Intelligence' UI code".
      // I will remove the import and the UI section.
      context.read<BookProvider>().loadBooks();
      context.read<DistributorProvider>().loadDistributors();
      context.read<CustomerProvider>().loadCustomers();
      context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            final shopName = settings.getSetting('shop_name');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName.isNotEmpty ? shopName : 'Home',
                    style: const TextStyle(fontSize: 20)),
                if (shopName.isNotEmpty)
                  Text(
                    settings.getSetting('shop_email'),
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<SalesProvider>().loadSales();
          await context.read<BookProvider>().loadBooks();
          await context.read<DistributorProvider>().loadDistributors();
          await context.read<CustomerProvider>().loadCustomers();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick Actions
              Text(
                'Quick Actions',
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
                    childAspectRatio: 1.3,
                    children: [
                      QuickActionCard(
                        title: 'Book Lookup',
                        icon: Icons.search,
                        color: AppTheme.infoText,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const BookListScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Sales',
                        icon: Icons.point_of_sale,
                        color: AppTheme.accent500,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PosScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Sales Return',
                        icon: Icons.assignment_return,
                        color: AppTheme.warningText,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const SalesReturnEntryScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Add Book',
                        icon: Icons.add_box,
                        color: AppTheme.successText,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AddEditBookScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Distributor',
                        icon: Icons.local_shipping,
                        color: AppTheme.accent700,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const DistributorListScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Customers',
                        icon: Icons.people,
                        color: AppTheme.infoText,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const CustomerListScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Purchase Return',
                        icon: Icons.assignment_return_outlined,
                        color: AppTheme.warningText,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PurchaseReturnEntryScreen()));
                        },
                      ),
                      QuickActionCard(
                        title: 'Purchase',
                        icon: Icons.add_shopping_cart,
                        color: AppTheme.accent500,
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PurchaseEntryScreen()));
                        },
                      ),
                    ],
                  );
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
