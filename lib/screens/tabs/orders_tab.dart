import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';
import '../../services/supabase_service.dart';
import 'package:intl/intl.dart';
import '../order_success_screen.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.getUserOrders();
      if (mounted) {
        setState(() {
          _orders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching orders: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Orders', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Past Orders'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(true, isDark),
                _buildOrderList(false, isDark),
              ],
            ),
    );
  }

  Widget _buildOrderList(bool isActive, bool isDark) {
    final filteredOrders = _orders.where((order) {
      final status = order['status'];
      final isCompleted = status == 'delivered' || status == 'cancelled';
      return isActive ? !isCompleted : isCompleted;
    }).toList();

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.restaurant_menu_outlined : Icons.history_rounded, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isActive ? 'No active orders' : 'No past orders yet',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order, isDark);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isDark) {
    final items = order['order_items'] as List;
    final date = DateTime.parse(order['created_at']).toLocal();
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final status = order['status'].toString();
    final isActive = status != 'delivered' && status != 'cancelled';

    return GestureDetector(
      onTap: isActive ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderData: {
                'id': order['id'],
                'delivery_pin': order['delivery_pin'],
                'total': order['total_amount'],
              },
            ),
          ),
        );
      } : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order ID & Status Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${order['id']}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(formattedDate, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                _buildStatusBadge(order['status']),
              ],
            ),
          ),
          const Divider(height: 1),
          // Items List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                final pizza = item['pizzas'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: pizza['image_url'] != null 
                          ? Image.network(pizza['image_url'], fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.local_pizza, color: AppColors.primary))
                          : const Icon(Icons.local_pizza, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${item['quantity']} x ${pizza['name']}',
                          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text('₹${item['price'].toInt()}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Footer Total
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                Text('₹${order['total_amount'].toInt()}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'pending': 
        color = Colors.orange; 
        label = 'PENDING';
        break;
      case 'preparing': 
        color = Colors.blue; 
        label = 'PREPARING';
        break;
      case 'on_the_way': 
        color = Colors.purple; 
        label = 'ON THE WAY';
        break;
      case 'delivered': 
        color = Colors.green; 
        label = 'DELIVERED';
        break;
      case 'cancelled': 
        color = Colors.red; 
        label = 'CANCELLED';
        break;
      default: 
        color = Colors.grey;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
