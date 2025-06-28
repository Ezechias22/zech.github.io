import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../shared/themes/app_theme.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  int _selectedPlanIndex = 1; // Plan mensuel par défaut
  
  final List<PremiumPlan> _plans = [
    PremiumPlan(
      title: 'Hebdomadaire',
      duration: '1 semaine',
      price: '4,99 €',
      originalPrice: '6,99 €',
      discount: '-29%',
      popular: false,
    ),
    PremiumPlan(
      title: 'Mensuel',
      duration: '1 mois',
      price: '14,99 €',
      originalPrice: '19,99 €',
      discount: '-25%',
      popular: true,
    ),
    PremiumPlan(
      title: 'Annuel',
      duration: '12 mois',
      price: '89,99 €',
      originalPrice: '179,88 €',
      discount: '-50%',
      popular: false,
      note: 'Soit 7,50€/mois',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // AppBar avec gradient
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFF6B6B),
                      Color(0xFFFF8E53),
                      Color(0xFFFFD93D),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Icône Premium avec animation
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.diamond,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Lovingo Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Débloquez tout le potentiel de l\'amour',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Contenu principal
          SliverToBoxAdapter(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Avantages Premium
                      _buildPremiumFeatures(),
                      const SizedBox(height: 32),
                      
                      // Plans de prix
                      _buildPricingSection(),
                      const SizedBox(height: 32),
                      
                      // Témoignages
                      _buildTestimonials(),
                      const SizedBox(height: 32),
                      
                      // Bouton d'achat
                      _buildPurchaseButton(),
                      const SizedBox(height: 16),
                      
                      // Informations légales
                      _buildLegalInfo(),
                      const SizedBox(height: 32),
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

  Widget _buildPremiumFeatures() {
    final features = [
      PremiumFeature(
        icon: Icons.visibility,
        title: 'Voir qui vous a liké',
        description: 'Découvrez tous vos admirateurs secrets',
        color: Colors.pink,
      ),
      PremiumFeature(
        icon: Icons.star,
        title: 'Super Likes illimités',
        description: 'Montrez votre intérêt sans limites',
        color: Colors.blue,
      ),
      PremiumFeature(
        icon: Icons.replay,
        title: 'Rewind illimité',
        description: 'Annulez vos swipes par erreur',
        color: Colors.orange,
      ),
      PremiumFeature(
        icon: Icons.flash_on,
        title: 'Boost mensuel',
        description: 'Soyez vu(e) 10x plus souvent',
        color: Colors.purple,
      ),
      PremiumFeature(
        icon: Icons.location_on,
        title: 'Passport',
        description: 'Rencontrez partout dans le monde',
        color: Colors.green,
      ),
      PremiumFeature(
        icon: Icons.block,
        title: 'Sans publicité',
        description: 'Expérience pure sans interruption',
        color: Colors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Avantages Premium',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...features.map((feature) => _buildFeatureItem(feature)).toList(),
      ],
    );
  }

  Widget _buildFeatureItem(PremiumFeature feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: feature.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              feature.icon,
              color: feature.color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  feature.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choisissez votre plan',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(_plans.length, (index) {
          final plan = _plans[index];
          return _buildPricingCard(plan, index);
        }),
      ],
    );
  }

  Widget _buildPricingCard(PremiumPlan plan, int index) {
    final isSelected = _selectedPlanIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!,
            width: 2,
          ),
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.05) : Colors.white,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Radio button
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.grey,
                        width: 2,
                      ),
                      color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  
                  // Plan info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (plan.popular) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'POPULAIRE',
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
                        Text(
                          plan.duration,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (plan.note != null)
                          Text(
                            plan.note!,
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (plan.discount != null) ...[
                        Text(
                          plan.originalPrice,
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          plan.discount!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      Text(
                        plan.price,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Popular badge
            if (plan.popular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.deepOrange],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'MEILLEURE OFFRE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestimonials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ce qu\'en disent nos utilisateurs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: PageView(
            children: [
              _buildTestimonialCard(
                'Sarah, 26 ans',
                'Grâce à Premium, j\'ai pu voir qui m\'avait liké et j\'ai trouvé l\'amour de ma vie ! 💕',
                '⭐⭐⭐⭐⭐',
              ),
              _buildTestimonialCard(
                'Marc, 32 ans',
                'Les Super Likes illimités m\'ont permis de me démarquer. Je recommande !',
                '⭐⭐⭐⭐⭐',
              ),
              _buildTestimonialCard(
                'Emma, 29 ans',
                'Le Passport est génial ! J\'ai rencontré des gens du monde entier.',
                '⭐⭐⭐⭐⭐',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestimonialCard(String name, String message, String rating) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rating,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton() {
    final selectedPlan = _plans[_selectedPlanIndex];
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _processPurchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 4,
            ),
            child: Text(
              'Débloquer Premium • ${selectedPlan.price}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Annulation possible à tout moment',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildLegalInfo() {
    return Column(
      children: [
        Text(
          'En continuant, vous acceptez nos Conditions d\'utilisation et notre Politique de confidentialité.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _showTerms,
              child: const Text('Conditions'),
            ),
            const Text(' • '),
            TextButton(
              onPressed: _showPrivacy,
              child: const Text('Confidentialité'),
            ),
            const Text(' • '),
            TextButton(
              onPressed: _showSupport,
              child: const Text('Support'),
            ),
          ],
        ),
      ],
    );
  }

  void _processPurchase() {
    final selectedPlan = _plans[_selectedPlanIndex];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'achat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Plan sélectionné: ${selectedPlan.title}'),
            Text('Prix: ${selectedPlan.price}'),
            const SizedBox(height: 16),
            const Text('Cette fonctionnalité nécessite l\'intégration d\'un système de paiement (App Store/Google Play).'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Système de paiement à implémenter'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showTerms() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conditions d\'utilisation'),
        content: const Text('Conditions d\'utilisation à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showPrivacy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Politique de confidentialité'),
        content: const Text('Politique de confidentialité à implémenter'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Premium'),
        content: const Text('Support technique à premium@lovingo.app'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Classes de données
class PremiumPlan {
  final String title;
  final String duration;
  final String price;
  final String originalPrice;
  final String? discount;
  final bool popular;
  final String? note;

  PremiumPlan({
    required this.title,
    required this.duration,
    required this.price,
    required this.originalPrice,
    this.discount,
    this.popular = false,
    this.note,
  });
}

class PremiumFeature {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  PremiumFeature({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}