import 'package:flutter/material.dart';
import 'stock_data_screen.dart';
import 'low_stock_screen.dart';
import 'expiry_alerts_screen.dart';

class StockHomeScreen extends StatelessWidget {
  const StockHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Management')),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            children: [
              _StockMenuCard(
                icon: Icons.data_usage,
                iconColor: Colors.deepPurple,
                title: 'Real-Time Stock Data',
                subtitle: 'View live stock and time data',
                background: [Color(0xFFEDE7F6), Color(0xFFD1C4E9)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StockDataScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),
              _StockMenuCard(
                icon: Icons.warning,
                iconColor: Colors.red,
                title: 'Low Stock Alerts',
                subtitle: 'Products below threshold',
                background: [Color(0xFFFFEBEE), Color(0xFFFFCDD2)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LowStockScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),
              _StockMenuCard(
                icon: Icons.timer,
                iconColor: Colors.deepOrange,
                title: 'Expiry Alerts',
                subtitle: 'Products nearing expiry',
                background: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpiryAlertsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockMenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Color> background;
  final VoidCallback onTap;

  const _StockMenuCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: background,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: background.last.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(18),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 15, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.deepPurple,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
