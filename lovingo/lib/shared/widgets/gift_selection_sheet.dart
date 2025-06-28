// lib/shared/widgets/gift_selection_sheet.dart - VERSION COMPLÈTE CORRIGÉE
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/gift_model.dart';
import '../../core/models/missing_models.dart'; // Pour WalletService et GiftCategorySimple

class GiftSelectionSheet extends ConsumerStatefulWidget {
  const GiftSelectionSheet({super.key});

  @override
  ConsumerState<GiftSelectionSheet> createState() => _GiftSelectionSheetState();
}

class _GiftSelectionSheetState extends ConsumerState<GiftSelectionSheet>
    with TickerProviderStateMixin {
  
  List<GiftModel> _gifts = [];
  List<GiftCategorySimple> _categories = [];
  String? _selectedCategoryId;
  String? _selectedGiftId;
  int _selectedQuantity = 1;
  bool _loading = true;
  int _userBalance = 0;
  
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOut,
    ));
    
    _loadGifts();
    _loadUserBalance();
    
    Future.microtask(() => _scaleController.forward());
  }

  Future<void> _loadGifts() async {
    try {
      setState(() {
        _categories = [
          GiftCategorySimple(id: 'common', name: 'Commun'),
          GiftCategorySimple(id: 'rare', name: 'Rare'), 
          GiftCategorySimple(id: 'epic', name: 'Épique'),
          GiftCategorySimple(id: 'legendary', name: 'Légendaire'),
        ];
        _gifts = DefaultGifts.gifts;
        _selectedCategoryId = 'common';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadUserBalance() async {
    try {
      final walletService = ref.read(walletServiceProvider);
      final balance = await walletService.getUserBalance('demo_user');
      setState(() {
        _userBalance = balance;
      });
    } catch (e) {
      setState(() {
        _userBalance = 1000;
      });
    }
  }

  List<GiftModel> get _filteredGifts {
    if (_selectedCategoryId == null) return _gifts;
    
    GiftRarity? targetRarity;
    switch (_selectedCategoryId) {
      case 'common':
        targetRarity = GiftRarity.common;
        break;
      case 'rare':
        targetRarity = GiftRarity.rare;
        break;
      case 'epic':
        targetRarity = GiftRarity.epic;
        break;
      case 'legendary':
        targetRarity = GiftRarity.legendary;
        break;
    }
    
    if (targetRarity == null) return _gifts;
    return _gifts.where((gift) => gift.rarity == targetRarity).toList();
  }

  int get _totalCost {
    if (_selectedGiftId == null) return 0;
    final gift = _gifts.firstWhere(
      (g) => g.id == _selectedGiftId,
      orElse: () => _gifts.first,
    );
    return gift.price * _selectedQuantity;
  }

  bool get _canAfford => _userBalance >= _totalCost;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF2D1B69),
                  Color(0xFF11002D),
                ],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoryTabs(),
                Expanded(
                  child: _loading ? _buildLoadingState() : _buildGiftGrid(),
                ),
                if (_selectedGiftId != null) _buildSelectionPanel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '🎁 Cadeaux Virtuels',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.yellow, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.yellow, size: 20),
                const SizedBox(width: 8),
                Text(
                  '$_userBalance',
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategoryId == category.id;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryId = category.id;
                _selectedGiftId = null;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Text(
                category.name,
                style: TextStyle(
                  color: isSelected ? Colors.purple : Colors.white,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Chargement des cadeaux...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    final gifts = _filteredGifts;
    
    if (gifts.isEmpty) {
      return const Center(
        child: Text(
          'Aucun cadeau disponible',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final isSelected = _selectedGiftId == gift.id;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedGiftId = gift.id;
              _selectedQuantity = 1;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      gift.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  gift.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${gift.price}',
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionPanel() {
    final selectedGift = _gifts.firstWhere(
      (g) => g.id == _selectedGiftId,
      orElse: () => _gifts.first,
    );
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Center(
                  child: Text(
                    selectedGift.icon,
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedGift.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Prix: ${selectedGift.price} × $_selectedQuantity = $_totalCost',
                      style: TextStyle(
                        color: _canAfford ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Quantité:',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              IconButton(
                onPressed: _selectedQuantity > 1 ? () {
                  setState(() {
                    _selectedQuantity--;
                  });
                } : null,
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_selectedQuantity',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: _selectedQuantity < 99 ? () {
                  setState(() {
                    _selectedQuantity++;
                  });
                } : null,
                icon: const Icon(Icons.add, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 5, 10, 50].map((quantity) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedQuantity = quantity;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedQuantity == quantity 
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedQuantity == quantity 
                          ? Colors.white
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '×$quantity',
                    style: TextStyle(
                      color: _selectedQuantity == quantity 
                          ? Colors.white
                          : Colors.white.withOpacity(0.7),
                      fontWeight: _selectedQuantity == quantity 
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canAfford ? _sendGift : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canAfford ? Colors.pink : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                _canAfford 
                    ? 'Envoyer Cadeau ($_totalCost)'
                    : 'Solde insuffisant',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (!_canAfford) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _rechargeBalance,
              child: const Text(
                'Recharger le solde',
                style: TextStyle(color: Colors.yellow),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _sendGift() {
    if (_selectedGiftId != null && _canAfford) {
      // Retourner le cadeau sélectionné au chat
      final selectedGift = _gifts.firstWhere((g) => g.id == _selectedGiftId);
      Navigator.pop(context, selectedGift);
    }
  }

  void _rechargeBalance() {
    // Simuler une recharge
    setState(() {
      _userBalance += 1000;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Solde rechargé de 1000 coins!')),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }
}