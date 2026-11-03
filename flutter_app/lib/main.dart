import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _tomato = Color(0xFFE45136);
const _ink = Color(0xFF28231F);
const _cream = Color(0xFFFFF9F1);
const _apiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:3000/api',
);

void main() {
  runApp(const JosjisPizzaApp());
}

class JosjisPizzaApp extends StatelessWidget {
  const JosjisPizzaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Josjis Pizza',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _cream,
        colorScheme: ColorScheme.fromSeed(seedColor: _tomato),
        fontFamily: 'Arial',
      ),
      home: const PizzaHomePage(),
    );
  }
}

class Pizza {
  const Pizza({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.emoji,
    this.badge,
  });

  final String id;
  final String name;
  final String description;
  final int price;
  final String category;
  final String emoji;
  final String? badge;

  factory Pizza.fromJson(Map<String, dynamic> json) => Pizza(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        price: json['price'] as int,
        category: json['category'] as String,
        emoji: json['emoji'] as String,
        badge: json['badge'] as String?,
      );
}

String _rupiah(int amount) {
  final digits = amount.toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'Rp$formatted';
}

class PizzaHomePage extends StatefulWidget {
  const PizzaHomePage({super.key});

  @override
  State<PizzaHomePage> createState() => _PizzaHomePageState();
}

class _PizzaHomePageState extends State<PizzaHomePage> {
  late Future<List<Pizza>> _menuRequest;
  final Map<String, int> _cart = {};
  String _category = 'Semua';
  bool _sendingOrder = false;

  @override
  void initState() {
    super.initState();
    _menuRequest = _loadMenu();
  }

  Future<List<Pizza>> _loadMenu() async {
    final response = await http.get(Uri.parse('$_apiUrl/menu'));
    if (response.statusCode != 200) {
      throw Exception('Menu belum bisa dimuat (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Pizza.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  int _quantity(String id) => _cart[id] ?? 0;

  void _updateCart(Pizza pizza, int change) {
    setState(() {
      final next = _quantity(pizza.id) + change;
      if (next <= 0) {
        _cart.remove(pizza.id);
      } else {
        _cart[pizza.id] = next;
      }
    });
  }

  Future<void> _checkout(List<Pizza> menu) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final details = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detail pengantaran'),
        content: Form(
          key: formKey,
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CheckoutField(controller: name, label: 'Nama lengkap'),
                const SizedBox(height: 12),
                _CheckoutField(
                  controller: phone,
                  label: 'Nomor telepon',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _CheckoutField(
                  controller: address,
                  label: 'Alamat pengantaran',
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, [
                  name.text.trim(),
                  phone.text.trim(),
                  address.text.trim(),
                ]);
              }
            },
            child: const Text('Pesan sekarang'),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    address.dispose();
    if (details == null || !mounted) return;

    setState(() => _sendingOrder = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': details[0],
          'phone': details[1],
          'address': details[2],
          'items': _cart.entries
              .map((entry) => {
                    'productId': entry.key,
                    'quantity': entry.value,
                  })
              .toList(),
        }),
      );
      if (response.statusCode != 201) {
        final message =
            (jsonDecode(response.body) as Map<String, dynamic>)['error'];
        throw Exception(message ?? 'Pesanan gagal dikirim.');
      }
      final order = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(_cart.clear);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 44),
          title: const Text('Pesanan berhasil!'),
          content: Text(
            'Pesanan #${(order['id'] as String).substring(0, 8)} diterima. '
            'Total ${_rupiah(order['total'] as int)}.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Selesai'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan belum terkirim: $error')),
      );
    } finally {
      if (mounted) setState(() => _sendingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Pizza>>(
          future: _menuRequest,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 42, color: _tomato),
                      const SizedBox(height: 12),
                      const Text(
                        'Menu belum bisa dimuat.',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Pastikan server Josjis Pizza sedang berjalan.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _menuRequest = _loadMenu();
                        }),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _tomato),
              );
            }
            return _buildShop(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildShop(List<Pizza> menu) {
    final categories = ['Semua', ...{for (final pizza in menu) pizza.category}];
    final pizzas = _category == 'Semua'
        ? menu
        : menu.where((pizza) => pizza.category == _category).toList();
    final cartPizzas =
        menu.where((pizza) => _quantity(pizza.id) > 0).toList();
    final total = cartPizzas.fold<int>(
      0,
      (sum, pizza) => sum + pizza.price * _quantity(pizza.id),
    );
    final width = MediaQuery.sizeOf(context).width;
    final showSidebar = width >= 980;

    return Column(
      children: [
        _TopBar(cartCount: _cart.values.fold(0, (a, b) => a + b)),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: width < 600 ? 18 : 32,
                  vertical: 24,
                ),
                child: showSidebar
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _menuContent(pizzas, categories),
                          ),
                          const SizedBox(width: 28),
                          SizedBox(
                            width: 320,
                            child: _CartPanel(
                              pizzas: cartPizzas,
                              quantity: _quantity,
                              total: total,
                              onChange: _updateCart,
                              onCheckout: () => _checkout(menu),
                              busy: _sendingOrder,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _menuContent(pizzas, categories)),
                          if (cartPizzas.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: _MobileCartBar(
                                count: _cart.values.fold(0, (a, b) => a + b),
                                total: total,
                                onTap: () => _showMobileCart(menu),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuContent(List<Pizza> pizzas, List<String> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeroBanner(),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Pilih pizza favoritmu',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ),
            const Icon(Icons.local_fire_department, color: _tomato, size: 20),
            const Text('Fresh from oven'),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = categories[index];
              return ChoiceChip(
                label: Text(category),
                selected: category == _category,
                onSelected: (_) => setState(() => _category = category),
                selectedColor: _tomato,
                labelStyle: TextStyle(
                  color: category == _category ? Colors.white : _ink,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700
                  ? 3
                  : constraints.maxWidth > 460
                      ? 2
                      : 1;
              return GridView.builder(
                itemCount: pizzas.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  mainAxisExtent: 267,
                ),
                itemBuilder: (context, index) => _PizzaCard(
                  pizza: pizzas[index],
                  quantity: _quantity(pizzas[index].id),
                  onChange: (change) => _updateCart(pizzas[index], change),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showMobileCart(List<Pizza> menu) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final cartPizzas =
              menu.where((pizza) => _quantity(pizza.id) > 0).toList();
          final total = cartPizzas.fold<int>(
            0,
            (sum, pizza) => sum + pizza.price * _quantity(pizza.id),
          );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.65,
                child: _CartPanel(
                  pizzas: cartPizzas,
                  quantity: _quantity,
                  total: total,
                  onChange: (pizza, change) {
                    _updateCart(pizza, change);
                    setModalState(() {});
                  },
                  onCheckout: () {
                    Navigator.pop(context);
                    _checkout(menu);
                  },
                  busy: _sendingOrder,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.cartCount});
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF0E8DE))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _tomato,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.local_pizza, color: Colors.white),
              ),
              const SizedBox(width: 11),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'josjis',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                      height: 1,
                    ),
                  ),
                  Text(
                    'PIZZA',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w700,
                      color: _tomato,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (MediaQuery.sizeOf(context).width > 600)
                const Row(
                  children: [
                    Icon(Icons.delivery_dining, color: _tomato, size: 20),
                    SizedBox(width: 7),
                    Text(
                      'Diantar hangat ke rumahmu',
                      style: TextStyle(color: _ink, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              const SizedBox(width: 24),
              Badge(
                isLabelVisible: cartCount > 0,
                label: Text('$cartCount'),
                backgroundColor: _tomato,
                child: const Icon(Icons.shopping_bag_outlined, color: _ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 26, 18, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF29251F),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF44352C),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PIZZA BAHAGIA, SETIAP HARI',
                    style: TextStyle(
                      color: Color(0xFFFFC08B),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Gigitan pertama,\nlangsung jatuh cinta.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Adonan fresh, topping melimpah, dibuat sepenuh hati.',
                  style: TextStyle(color: Color(0xFFD8CEC2), fontSize: 12),
                ),
                const SizedBox(height: 15),
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Color(0xFFFFC08B), size: 17),
                    SizedBox(width: 3),
                    Text(
                      'Gratis ongkir min. Rp100.000',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('🍕', style: TextStyle(fontSize: 78)),
        ],
      ),
    );
  }
}

class _PizzaCard extends StatelessWidget {
  const _PizzaCard({
    required this.pizza,
    required this.quantity,
    required this.onChange,
  });

  final Pizza pizza;
  final int quantity;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1EAE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE9CF), Color(0xFFFFF4E6)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(pizza.emoji, style: const TextStyle(fontSize: 60)),
                  ),
                ),
                if (pizza.badge != null)
                  Positioned(
                    left: 9,
                    top: 9,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _tomato,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pizza.badge!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Text(
            pizza.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pizza.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF80766E), fontSize: 11),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _rupiah(pizza.price),
                  style: const TextStyle(
                    color: _tomato,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (quantity == 0)
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: () => onChange(1),
                    style: FilledButton.styleFrom(
                      backgroundColor: _tomato,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '+ Tambah',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else
                _QuantityControl(quantity: quantity, onChange: onChange),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({required this.quantity, required this.onChange});
  final int quantity;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _roundButton(Icons.remove, () => onChange(-1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        _roundButton(Icons.add, () => onChange(1)),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onPressed) => InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(color: Color(0xFFFFEEE7), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: _tomato),
        ),
      );
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({
    required this.pizzas,
    required this.quantity,
    required this.total,
    required this.onChange,
    required this.onCheckout,
    required this.busy,
  });

  final List<Pizza> pizzas;
  final int Function(String) quantity;
  final int total;
  final void Function(Pizza, int) onChange;
  final VoidCallback onCheckout;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1EAE2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Keranjang kamu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${pizzas.fold<int>(0, (sum, pizza) => sum + quantity(pizza.id))} item',
                style: const TextStyle(color: Color(0xFF80766E), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (pizzas.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🛍️', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text(
                      'Keranjang masih kosong',
                      style: TextStyle(color: Color(0xFF80766E)),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: pizzas.length,
                separatorBuilder: (_, __) => const Divider(height: 22),
                itemBuilder: (context, index) {
                  final pizza = pizzas[index];
                  return Row(
                    children: [
                      Text(pizza.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pizza.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${quantity(pizza.id)} × ${_rupiah(pizza.price)}',
                              style: const TextStyle(
                                color: Color(0xFF80766E),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _QuantityControl(
                        quantity: quantity(pizza.id),
                        onChange: (change) => onChange(pizza, change),
                      ),
                    ],
                  );
                },
              ),
            ),
          const Divider(height: 26),
          const Row(
            children: [
              Icon(Icons.delivery_dining, color: _tomato, size: 19),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Biaya pengantaran',
                  style: TextStyle(fontSize: 12, color: Color(0xFF80766E)),
                ),
              ),
              Text(
                'Gratis',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total pembayaran',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _rupiah(total),
                style: const TextStyle(
                  color: _tomato,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: pizzas.isEmpty || busy ? null : onCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: _tomato,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Text(
                busy ? 'Mengirim pesanan...' : 'Lanjut checkout  →',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCartBar extends StatelessWidget {
  const _MobileCartBar({
    required this.count,
    required this.total,
    required this.onTap,
  });
  final int count;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: _ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Row(
          children: [
            Badge(
              label: Text('$count'),
              backgroundColor: _tomato,
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Lihat keranjang', style: TextStyle(color: Colors.white)),
            ),
            Text(
              _rupiah(total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          value == null || value.trim().isEmpty ? '$label wajib diisi' : null,
    );
  }
}
