import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/wallet_service.dart';
import '../../core/services/currency_service.dart';
import '../../shared/themes/app_theme.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _balanceAnimationController;
  late AnimationController _cardAnimationController;
  
  final _amountController = TextEditingController();
  final _scrollController = ScrollController();
  
  // Variables d'état pour animations
  late Animation<double> _balanceScaleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isBalanceVisible = true;
  int _selectedTopUpAmount = -1;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _setupAnimations();
    _loadWalletData();
  }

  void _initializeControllers() {
    _tabController = TabController(length: 3, vsync: this);
    _balanceAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  void _setupAnimations() {
    _balanceScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _balanceAnimationController,
      curve: Curves.elasticOut,
    ));

    _cardSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeIn,
    ));

    // Démarrer les animations
    _balanceAnimationController.forward();
    _cardAnimationController.forward();
  }

  void _loadWalletData() {
    // Charger les données du wallet de manière asynchrone
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletServiceProvider.notifier).refreshWallet();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final walletState = ref.watch(walletServiceProvider);
    final currencyState = ref.watch(currencyServiceProvider);
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar avec gradient et animations
          _buildAnimatedAppBar(user, currencyState),
          
          // Contenu principal
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Actions rapides avec animations
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(_cardSlideAnimation),
                      child: _buildQuickActions(),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Statistiques du wallet
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.7),
                        end: Offset.zero,
                      ).animate(_cardSlideAnimation),
                      child: _buildWalletStats(user, walletState),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Onglets avec animations
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.9),
                        end: Offset.zero,
                      ).animate(_cardSlideAnimation),
                      child: _buildTabSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedAppBar(user, currencyState) {
    return SliverAppBar(
      expandedHeight: 220,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Mon Portefeuille',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 3,
                color: Colors.black26,
              ),
            ],
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const SizedBox(height: 60),
                  // Solde principal avec animation
                  ScaleTransition(
                    scale: _balanceScaleAnimation,
                    child: _buildBalanceCard(user.wallet?.balance ?? 0.0, currencyState),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        // Bouton pour masquer/afficher le solde
        IconButton(
          icon: Icon(
            _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isBalanceVisible = !_isBalanceVisible;
            });
            HapticFeedback.lightImpact();
          },
        ),
        // Menu des paramètres
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download, size: 20),
                  SizedBox(width: 8),
                  Text('Exporter'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'security',
              child: Row(
                children: [
                  Icon(Icons.security, size: 20),
                  SizedBox(width: 8),
                  Text('Sécurité'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help, size: 20),
                  SizedBox(width: 8),
                  Text('Aide'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBalanceCard(double balance, currencyState) {
    final currencyService = ref.read(currencyServiceProvider.notifier);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Solde disponible',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Indicateur de monnaie auto-détectée
              if (currencyState.isAutoDetected) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'AUTO',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Affichage du solde avec option de masquage
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isBalanceVisible
                ? Text(
                    currencyService.formatAmount(balance),
                    key: const ValueKey('visible'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  )
                : Text(
                    '••••••',
                    key: const ValueKey('hidden'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
          ),
          
          const SizedBox(height: 8),
          
          // Informations sur la monnaie
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.location_on,
                color: Colors.white.withOpacity(0.8),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${currencyState.countryCode} • ${currencyState.currentCurrency}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'title': 'Recharger',
        'icon': Icons.add_circle_outline,
        'color': AppTheme.primaryColor,
        'onTap': _showTopUpDialog,
      },
      {
        'title': 'Retirer',
        'icon': Icons.remove_circle_outline,
        'color': Colors.orange,
        'onTap': _showWithdrawDialog,
      },
      {
        'title': 'Historique',
        'icon': Icons.history,
        'color': Colors.blue,
        'onTap': _showTransactionHistory,
      },
      {
        'title': 'Envoyer',
        'icon': Icons.send,
        'color': Colors.green,
        'onTap': _showSendMoneyDialog,
      },
    ];

    return Row(
      children: actions.map((action) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionButton(
              action['title'] as String,
              action['icon'] as IconData,
              action['color'] as Color,
              action['onTap'] as VoidCallback,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletStats(user, walletState) {
    final currencyService = ref.read(currencyServiceProvider.notifier);
    
    return Card(
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Statistiques',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Statistiques principales
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Gains totaux',
                    currencyService.formatAmount(user.wallet?.totalEarnings ?? 0.0),
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'En attente',
                    currencyService.formatAmount(user.wallet?.pendingWithdrawal ?? 0.0),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Méthode de paiement
            _buildPaymentMethodSection(user.wallet?.paymentMethod),
            
            const SizedBox(height: 16),
            
            // Section de changement de monnaie
            _buildCurrencySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(String? paymentMethod) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              paymentMethod != null ? Icons.credit_card : Icons.add_card,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentMethod != null ? 'Méthode de paiement' : 'Ajouter une méthode',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  paymentMethod ?? 'Aucune méthode configurée',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showPaymentMethodDialog,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
            child: Text(paymentMethod != null ? 'Modifier' : 'Ajouter'),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySection() {
    final currencyState = ref.watch(currencyServiceProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.currency_exchange,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Monnaie',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (currencyState.isAutoDetected) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AUTO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${currencyState.currentCurrency} (${currencyState.currencySymbol}) - ${_getCurrencyName(currencyState.currentCurrency)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showCurrencySelector,
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
            ),
            child: const Text('Changer'),
          ),
        ],
      ),
    );
  }

  String _getCurrencyName(String currencyCode) {
    final names = {
      'EUR': 'Euro',
      'USD': 'Dollar US',
      'GBP': 'Livre Sterling',
      'CAD': 'Dollar Canadien',
      'AUD': 'Dollar Australien',
      'JPY': 'Yen Japonais',
      'CHF': 'Franc Suisse',
      'BRL': 'Real Brésilien',
      'CNY': 'Yuan Chinois',
      'INR': 'Roupie Indienne',
      'KRW': 'Won Sud-Coréen',
      'MXN': 'Peso Mexicain',
      'RUB': 'Rouble Russe',
      'ZAR': 'Rand Sud-Africain',
    };
    return names[currencyCode] ?? currencyCode;
  }

  Widget _buildTabSection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryColor,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
            tabs: const [
              Tab(
                icon: Icon(Icons.receipt_long),
                text: 'Transactions',
              ),
              Tab(
                icon: Icon(Icons.card_giftcard),
                text: 'Cadeaux',
              ),
              Tab(
                icon: Icon(Icons.settings),
                text: 'Paramètres',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionsTab(),
              _buildGiftsTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final currencyService = ref.read(currencyServiceProvider.notifier);
        
        // Mock transactions data
        final transactions = [
          {
            'title': 'Recharge par carte',
            'amount': 25.0,
            'date': 'Aujourd\'hui, 14:30',
            'icon': Icons.add_circle,
            'color': Colors.green,
            'type': 'credit',
          },
          {
            'title': 'Cadeau envoyé',
            'amount': -2.50,
            'date': 'Hier, 19:45',
            'icon': Icons.card_giftcard,
            'color': Colors.pink,
            'type': 'debit',
          },
          {
            'title': 'Pourboire reçu',
            'amount': 5.0,
            'date': 'Hier, 16:20',
            'icon': Icons.favorite,
            'color': Colors.red,
            'type': 'credit',
          },
          {
            'title': 'Retrait',
            'amount': -50.0,
            'date': '2 jours, 10:15',
            'icon': Icons.remove_circle,
            'color': Colors.orange,
            'type': 'debit',
          },
        ];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return _buildTransactionItem(
              transaction['title'] as String,
              transaction['amount'] as double,
              transaction['date'] as String,
              transaction['icon'] as IconData,
              transaction['color'] as Color,
              transaction['type'] as String,
              currencyService,
            );
          },
        );
      },
    );
  }

  Widget _buildTransactionItem(
    String title,
    double amount,
    String date,
    IconData icon,
    Color color,
    String type,
    currencyService,
  ) {
    final isCredit = type == 'credit';
    final formattedAmount = '${isCredit ? '+' : ''} ${currencyService.formatAmount(amount.abs())}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formattedAmount,
            style: TextStyle(
              color: isCredit ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Statistiques des cadeaux
          Row(
            children: [
              Expanded(
                child: _buildGiftStat('Reçus', '12', Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGiftStat('Envoyés', '8', Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Historique des cadeaux
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final currencyService = ref.read(currencyServiceProvider.notifier);
                
                return ListView.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return _buildGiftItem(
                      'Rose virtuelle',
                      'Reçu de Sarah',
                      currencyService.formatAmount(2.50),
                      Icons.local_florist,
                      Colors.pink,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftStat(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              color: color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftItem(
    String title,
    String subtitle,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Paramètres de notification
          _buildSettingItem(
            'Notifications de paiement',
            'Recevoir des alertes pour les transactions',
            Icons.notifications,
            true,
            (value) {
              // Implémenter la logique de notification
              HapticFeedback.selectionClick();
            },
          ),
          
          _buildSettingItem(
            'Recharge automatique',
            'Recharger quand le solde est bas',
            Icons.autorenew,
            false,
            (value) {
              // Implémenter la recharge automatique
              HapticFeedback.selectionClick();
            },
          ),
          
          _buildSettingItem(
            'Historique détaillé',
            'Afficher tous les détails des transactions',
            Icons.receipt_long,
            true,
            (value) {
              // Implémenter l'historique détaillé
              HapticFeedback.selectionClick();
            },
          ),
          
          const SizedBox(height: 20),
          
          // Actions de paramètres
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildActionListTile(
                  Icons.download,
                  'Exporter l\'historique',
                  'Télécharger vos transactions',
                  Colors.blue,
                  _exportHistory,
                ),
                const Divider(height: 1),
                _buildActionListTile(
                  Icons.help,
                  'Aide & Support',
                  'Contactez notre équipe',
                  Colors.green,
                  _showHelp,
                ),
                const Divider(height: 1),
                _buildActionListTile(
                  Icons.security,
                  'Sécurité du portefeuille',
                  'Paramètres de sécurité',
                  Colors.orange,
                  _showSecuritySettings,
                ),
                const Divider(height: 1),
                _buildActionListTile(
                  Icons.backup,
                  'Sauvegarde automatique',
                  'Sauvegarder vos données',
                  Colors.purple,
                  _showBackupSettings,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Section danger zone
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Zone dangereuse',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildActionListTile(
                    Icons.delete_forever,
                    'Supprimer l\'historique',
                    'Effacer toutes les transactions',
                    Colors.red,
                    _showDeleteHistoryDialog,
                    isDangerous: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildActionListTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap, {
    bool isDangerous = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isDangerous ? Colors.red : null,
        ),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  // Méthodes d'actions et dialogues

  void _showTopUpDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTopUpBottomSheet(),
    );
  }

  Widget _buildTopUpBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Contenu
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_circle,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Recharger le portefeuille',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Montants prédéfinis
                  const Text(
                    'Montants suggérés',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final currencyService = ref.read(currencyServiceProvider.notifier);
                      final amounts = [5, 10, 20, 50, 100];
                      
                      return Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: amounts.asMap().entries.map((entry) {
                          final index = entry.key;
                          final amount = entry.value;
                          final isSelected = _selectedTopUpAmount == index;
                          
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTopUpAmount = index;
                                _amountController.text = amount.toString();
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppTheme.primaryColor
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? AppTheme.primaryColor
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: Text(
                                currencyService.formatAmount(amount.toDouble()),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Montant personnalisé
                  const Text(
                    'Montant personnalisé',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final currencyState = ref.watch(currencyServiceProvider);
                      
                      return TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Entrez le montant',
                          suffixText: currencyState.currencySymbol,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppTheme.primaryColor),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedTopUpAmount = -1;
                          });
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Méthodes de paiement
                  const Text(
                    'Méthode de paiement',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildPaymentMethodSelector(),
                  
                  const Spacer(),
                  
                  // Bouton de recharge
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processTopUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Consumer(
                        builder: (context, ref, child) {
                          final currencyService = ref.read(currencyServiceProvider.notifier);
                          final amount = double.tryParse(_amountController.text) ?? 0.0;
                          
                          return Text(
                            amount > 0 
                                ? 'Recharger ${currencyService.formatAmount(amount)}'
                                : 'Recharger',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
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

  Widget _buildPaymentMethodSelector() {
    final paymentMethods = [
      {'name': 'Carte bancaire', 'icon': Icons.credit_card, 'enabled': true},
      {'name': 'PayPal', 'icon': Icons.payment, 'enabled': true},
      {'name': 'Apple Pay', 'icon': Icons.phone_iphone, 'enabled': false},
      {'name': 'Google Pay', 'icon': Icons.android, 'enabled': false},
    ];

    return Column(
      children: paymentMethods.map((method) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: method['enabled'] as bool ? Colors.white : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: method['enabled'] as bool ? Colors.grey[300]! : Colors.grey[200]!,
            ),
          ),
          child: ListTile(
            leading: Icon(
              method['icon'] as IconData,
              color: method['enabled'] as bool ? AppTheme.primaryColor : Colors.grey,
            ),
            title: Text(
              method['name'] as String,
              style: TextStyle(
                color: method['enabled'] as bool ? Colors.black : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: method['enabled'] as bool 
                ? const Icon(Icons.chevron_right)
                : const Text(
                    'Bientôt',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
            enabled: method['enabled'] as bool,
            onTap: method['enabled'] as bool 
                ? () {
                    HapticFeedback.selectionClick();
                    // Implémenter la sélection de méthode de paiement
                  }
                : null,
          ),
        );
      }).toList(),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.remove_circle, color: Colors.orange),
            SizedBox(width: 8),
            Text('Retirer des fonds'),
          ],
        ),
        content: const Text(
          'Fonction de retrait à implémenter avec votre système de paiement.\n\nMinimum de retrait: 10€\nDélai de traitement: 1-3 jours ouvrés',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémenter le retrait
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }

  void _showSendMoneyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send, color: Colors.green),
            SizedBox(width: 8),
            Text('Envoyer de l\'argent'),
          ],
        ),
        content: const Text(
          'Envoyez de l\'argent à d\'autres utilisateurs de l\'application.\n\nFonctionnalité à implémenter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTransactionHistory() {
    _tabController.animateTo(0);
    HapticFeedback.selectionClick();
  }

  void _showPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.credit_card, color: Colors.blue),
            SizedBox(width: 8),
            Text('Méthode de paiement'),
          ],
        ),
        content: const Text(
          'Configuration des méthodes de paiement.\n\nVous pourrez ajouter:\n• Cartes bancaires\n• PayPal\n• Comptes bancaires',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémenter l'ajout de méthode de paiement
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Configurer'),
          ),
        ],
      ),
    );
  }

  void _processTopUp() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Text('Montant invalide'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    
    Navigator.pop(context);
    
    final currencyService = ref.read(currencyServiceProvider.notifier);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text('Recharge de ${currencyService.formatAmount(amount)} à implémenter'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    
    // Reset du formulaire
    _amountController.clear();
    _selectedTopUpAmount = -1;
  }

  void _exportHistory() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.download, color: Colors.white),
            SizedBox(width: 8),
            Text('Export de l\'historique en cours...'),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help, color: Colors.green),
            SizedBox(width: 8),
            Text('Aide & Support'),
          ],
        ),
        content: const Text(
          'Pour toute question concernant votre portefeuille:\n\n'
          '📧 Email: wallet@lovingo.app\n'
          '📞 Téléphone: +33 1 23 45 67 89\n'
          '💬 Chat en direct: Disponible 24h/7j\n\n'
          'Temps de réponse moyen: 2h',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Ouvrir le chat de support
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Chat en direct'),
          ),
        ],
      ),
    );
  }

  void _showSecuritySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sécurité'),
          ],
        ),
        content: const Text(
          'Paramètres de sécurité disponibles:\n\n'
          '🔐 Authentification à deux facteurs\n'
          '🔒 Code PIN pour les transactions\n'
          '👆 Authentification biométrique\n'
          '🚨 Alertes de sécurité\n'
          '📊 Historique des connexions',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Ouvrir les paramètres de sécurité
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Configurer'),
          ),
        ],
      ),
    );
  }

  void _showBackupSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.backup, color: Colors.purple),
            SizedBox(width: 8),
            Text('Sauvegarde'),
          ],
        ),
        content: const Text(
          'Options de sauvegarde:\n\n'
          '☁️ Sauvegarde cloud automatique\n'
          '📱 Sauvegarde locale\n'
          '🔄 Synchronisation multi-appareils\n'
          '📤 Export manuel des données\n\n'
          'Dernière sauvegarde: Aujourd\'hui à 14:30',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Effectuer une sauvegarde maintenant
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  void _showDeleteHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Attention!'),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer tout l\'historique des transactions?\n\n'
          'Cette action est irréversible et supprimera définitivement:\n'
          '• Toutes les transactions\n'
          '• L\'historique des cadeaux\n'
          '• Les statistiques\n\n'
          'Les données de solde actuel seront conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémenter la suppression
              HapticFeedback.heavyImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.delete, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Historique supprimé'),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showCurrencySelector() {
    final currencyState = ref.read(currencyServiceProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.currency_exchange,
                      color: Colors.blue[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choisir une monnaie',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            
            // Info auto-détection
            if (currencyState.isAutoDetected)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Monnaie détectée automatiquement selon votre localisation',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Liste des monnaies
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: currencyState.availableCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = currencyState.availableCurrencies[index];
                  final isSelected = currency.code == currencyState.currentCurrency;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.grey[200],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            currency.symbol,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[600],
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        '${currency.name} (${currency.code})',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? AppTheme.primaryColor : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        currency.countryName,
                        style: TextStyle(
                          color: isSelected ? AppTheme.primaryColor.withOpacity(0.7) : Colors.grey[600],
                        ),
                      ),
                      trailing: isSelected 
                          ? Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : null,
                      onTap: () async {
                        HapticFeedback.selectionClick();
                        
                        // Afficher un indicateur de chargement
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                        
                        try {
                          await ref.read(currencyServiceProvider.notifier).changeCurrency(currency.code);
                          
                          Navigator.pop(context); // Fermer le loader
                          Navigator.pop(context); // Fermer le sélecteur
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('Monnaie changée vers ${currency.name}'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        } catch (e) {
                          Navigator.pop(context); // Fermer le loader
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text('Erreur lors du changement de monnaie'),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            
            // Footer avec info
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le changement de monnaie affectera l\'affichage de tous les montants dans l\'application.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    HapticFeedback.selectionClick();
    
    switch (action) {
      case 'export':
        _exportHistory();
        break;
      case 'security':
        _showSecuritySettings();
        break;
      case 'help':
        _showHelp();
        break;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _scrollController.dispose();
    _balanceAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }
}