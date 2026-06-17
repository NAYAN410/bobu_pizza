import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<Map<String, dynamic>> _activeOrders = [
    {
      'id': '#ORD-2847',
      'date': 'Today, 2:30 PM',
      'items': 'Pepperoni × 1, Garlic Bread × 1',
      'total': '₹448',
      'step': 2,
      'steps': ['Placed', 'Preparing', 'On the Way', 'Delivered'],
    },
  ];

  final List<Map<String, dynamic>> _pastOrders = [
    {
      'id': '#ORD-2801',
      'date': 'Yesterday, 7:15 PM',
      'items': 'Cheese Burst × 2, Pepsi × 2',
      'total': '₹676',
      'step': 3,
      'steps': ['Placed', 'Preparing', 'On the Way', 'Delivered'],
    },
    {
      'id': '#ORD-2765',
      'date': '12 Jun, 1:00 PM',
      'items': 'Margherita × 1, Lemonade × 1',
      'total': '₹328',
      'step': 3,
      'steps': ['Placed', 'Preparing', 'On the Way', 'Delivered'],
    },
    {
      'id': '#ORD-2700',
      'date': '8 Jun, 8:45 PM',
      'items': 'BBQ Chicken × 1, Wings × 1',
      'total': '₹578',
      'step': 3,
      'steps': ['Placed', 'Preparing', 'On the Way', 'Delivered'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final double scale = (sw.clamp(0.0, 430.0) / 375).clamp(0.85, 1.1);
    final double bottomPad = MediaQuery.of(context).padding.bottom + 72;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20 * scale, 16 * scale, 20 * scale, 16 * scale),
              child: Text(
                'My Orders',
                style: GoogleFonts.poppins(
                  fontSize: 24 * scale,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D1A0E),
                ),
              ),
            ),

            // ── Tab switcher ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20 * scale),
              child: Container(
                height: 44 * scale,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE8D5C0), width: 1),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor:
                  const Color(0xFF2D1A0E).withOpacity(0.5),
                  labelStyle: GoogleFonts.poppins(
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                  GoogleFonts.poppins(fontSize: 13 * scale),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Active'),
                    Tab(text: 'Past Orders'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16 * scale),

            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [

                  // Active orders
                  _activeOrders.isEmpty
                      ? _buildEmpty('No active orders', '🛵', scale)
                      : ListView.builder(
                    padding: EdgeInsets.only(
                      left: 16 * scale,
                      right: 16 * scale,
                      bottom: bottomPad, // ← nav bar + system inset
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _activeOrders.length,
                    itemBuilder: (context, i) => _buildOrderCard(
                        _activeOrders[i], scale, true),
                  ),

                  // Past orders
                  _pastOrders.isEmpty
                      ? _buildEmpty('No past orders', '📋', scale)
                      : ListView.builder(
                    padding: EdgeInsets.only(
                      left: 16 * scale,
                      right: 16 * scale,
                      bottom: bottomPad, // ← nav bar + system inset
                    ),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _pastOrders.length,
                    itemBuilder: (context, i) => _buildOrderCard(
                        _pastOrders[i], scale, false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String msg, String emoji, double scale) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 56 * scale)),
          SizedBox(height: 12 * scale),
          Text(
            msg,
            style: GoogleFonts.poppins(
              fontSize: 16 * scale,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D1A0E).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
      Map<String, dynamic> order, double scale, bool isActive) {
    final int currentStep = order['step'] as int;
    final List<String> steps = List<String>.from(order['steps']);

    return Container(
      margin: EdgeInsets.only(bottom: 14 * scale),
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8D5C0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D1A0E).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Top row — ID + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order['id'],
                style: GoogleFonts.poppins(
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D1A0E),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10 * scale, vertical: 4 * scale),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? '🔥 Active' : '✅ Delivered',
                  style: GoogleFonts.poppins(
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? AppColors.primary
                        : Colors.green[700],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 4 * scale),

          // Date
          Text(
            order['date'],
            style: GoogleFonts.poppins(
              fontSize: 11 * scale,
              color: const Color(0xFF2D1A0E).withOpacity(0.4),
            ),
          ),

          SizedBox(height: 4 * scale),

          // Items
          Text(
            order['items'],
            style: GoogleFonts.poppins(
              fontSize: 12 * scale,
              color: const Color(0xFF2D1A0E).withOpacity(0.6),
            ),
          ),

          SizedBox(height: 16 * scale),

          // Timeline
          _buildTimeline(steps, currentStep, scale),

          SizedBox(height: 14 * scale),

          Divider(
              color: const Color(0xFF2D1A0E).withOpacity(0.08),
              height: 1),

          SizedBox(height: 12 * scale),

          // Bottom row — total + action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order['total'],
                style: GoogleFonts.poppins(
                  fontSize: 15 * scale,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              if (!isActive)
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16 * scale, vertical: 7 * scale),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Reorder',
                      style: GoogleFonts.poppins(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              if (isActive)
                Text(
                  'Est. 15 mins ⏱',
                  style: GoogleFonts.poppins(
                    fontSize: 12 * scale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D1A0E).withOpacity(0.45),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
      List<String> steps, int currentStep, double scale) {
    return Row(
      children: List.generate(steps.length, (i) {
        final isDone = i <= currentStep;
        final isLast = i == steps.length - 1;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 26 * scale,
                    height: 26 * scale,
                    decoration: BoxDecoration(
                      color: isDone ? AppColors.primary : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDone
                            ? AppColors.primary
                            : const Color(0xFFE8D5C0),
                        width: 1.5,
                      ),
                      boxShadow: isDone
                          ? [
                        BoxShadow(
                          color:
                          AppColors.primary.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                          : [],
                    ),
                    child: Icon(
                      _stepIcon(i),
                      size: 13 * scale,
                      color: isDone
                          ? Colors.white
                          : const Color(0xFF2D1A0E).withOpacity(0.25),
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    steps[i],
                    style: GoogleFonts.poppins(
                      fontSize: 8 * scale,
                      fontWeight: isDone
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isDone
                          ? AppColors.primary
                          : const Color(0xFF2D1A0E).withOpacity(0.3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: EdgeInsets.only(bottom: 18 * scale),
                    decoration: BoxDecoration(
                      color: i < currentStep
                          ? AppColors.primary
                          : const Color(0xFFE8D5C0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  IconData _stepIcon(int step) {
    switch (step) {
      case 0:  return Icons.receipt_long_rounded;
      case 1:  return Icons.local_fire_department_rounded;
      case 2:  return Icons.delivery_dining_rounded;
      case 3:  return Icons.check_rounded;
      default: return Icons.circle;
    }
  }
}