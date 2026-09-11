import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../screens/home_screen.dart';
import '../screens/sales/sales_entry_screen.dart';
import '../screens/inventory/book_list_screen.dart';
import '../screens/purchase/purchase_entry_screen.dart';
import '../screens/purchase/purchase_list_screen.dart';
import '../screens/distributor/distributor_list_screen.dart';
import '../screens/customer/customer_list_screen.dart';
import '../screens/sales/sales_list_screen.dart';
import '../screens/purchase_return/purchase_return_entry_screen.dart';
import '../screens/purchase_return/purchase_return_list_screen.dart';
import '../screens/sales_return/sales_return_entry_screen.dart';
import '../screens/sales_return/sales_return_list_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/report/report_screen.dart';
import '../screens/settlement/settlement_filter_screen.dart';
import '../screens/settings/about_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.accent500,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Image.asset('assets/images/launcher_icon.png',
                    width: 64, height: 64, fit: BoxFit.contain),
                const SizedBox(height: 16),
                Text(
                  'Book Store POS',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.dashboard,
            title: 'Home',
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.bar_chart,
            title: 'Daily Reports',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.published_with_changes,
            title: 'Sale or Return Settlement',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettlementFilterScreen(),
              ),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.inventory_2,
            title: 'Inventory',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookListScreen()),
            ),
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.people,
            title: 'Customers',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.local_shipping,
            title: 'Distributors',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DistributorListScreen()),
            ),
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.point_of_sale,
            title: 'Sales',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PosScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.receipt_long,
            title: 'Sales History',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesListScreen()),
            ),
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.assignment_return,
            title: 'Sales Return',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesReturnEntryScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.history,
            title: 'Sales Return History',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesReturnListScreen()),
            ),
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.add_shopping_cart,
            title: 'Purchase',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseEntryScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.receipt_long,
            title: 'Purchase History',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen()),
            ),
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.assignment_return_outlined,
            title: 'Purchase Return',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PurchaseReturnEntryScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.history,
            title: 'Purchase Return History',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PurchaseReturnListScreen()),
            ),
          ),
          const Divider(),
          _buildNavItem(
            context,
            icon: Icons.settings,
            title: 'Settings',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          _buildNavItem(
            context,
            icon: Icons.info_outline,
            title: 'About',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent500),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }
}
