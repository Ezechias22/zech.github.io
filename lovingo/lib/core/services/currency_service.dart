import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

// =============================================================================
// PROVIDERS
// =============================================================================

final currencyServiceProvider = StateNotifierProvider<CurrencyService, CurrencyState>(
  (ref) => CurrencyService(),
);

// =============================================================================
// ÉTATS ET MODÈLES
// =============================================================================

class CurrencyState {
  final String currentCurrency;
  final String currencySymbol;
  final String countryCode;
  final bool isAutoDetected;
  final bool isLoading;
  final List<Currency> availableCurrencies;

  const CurrencyState({
    this.currentCurrency = 'EUR',
    this.currencySymbol = '€',
    this.countryCode = 'FR',
    this.isAutoDetected = false,
    this.isLoading = false,
    this.availableCurrencies = const [],
  });

  CurrencyState copyWith({
    String? currentCurrency,
    String? currencySymbol,
    String? countryCode,
    bool? isAutoDetected,
    bool? isLoading,
    List<Currency>? availableCurrencies,
  }) {
    return CurrencyState(
      currentCurrency: currentCurrency ?? this.currentCurrency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      countryCode: countryCode ?? this.countryCode,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
      isLoading: isLoading ?? this.isLoading,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
    );
  }
}

class Currency {
  final String code;
  final String symbol;
  final String name;
  final String countryCode;
  final String countryName;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.countryCode,
    required this.countryName,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'] ?? '',
      symbol: json['symbol'] ?? '',
      name: json['name'] ?? '',
      countryCode: json['countryCode'] ?? '',
      countryName: json['countryName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
      'countryCode': countryCode,
      'countryName': countryName,
    };
  }
}

// =============================================================================
// SERVICE DE GESTION DES MONNAIES
// =============================================================================

class CurrencyService extends StateNotifier<CurrencyState> {
  CurrencyService() : super(const CurrencyState()) {
    initialize();
  }

  // Mapping pays -> monnaie (Base de données des monnaies)
  static const Map<String, Currency> _countryCurrencies = {
    // Europe
    'FR': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'FR', countryName: 'France'),
    'DE': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'DE', countryName: 'Allemagne'),
    'IT': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'IT', countryName: 'Italie'),
    'ES': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'ES', countryName: 'Espagne'),
    'NL': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'NL', countryName: 'Pays-Bas'),
    'BE': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'BE', countryName: 'Belgique'),
    'AT': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'AT', countryName: 'Autriche'),
    'PT': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'PT', countryName: 'Portugal'),
    'GB': Currency(code: 'GBP', symbol: '£', name: 'Livre Sterling', countryCode: 'GB', countryName: 'Royaume-Uni'),
    'CH': Currency(code: 'CHF', symbol: 'CHF', name: 'Franc Suisse', countryCode: 'CH', countryName: 'Suisse'),
    'SE': Currency(code: 'SEK', symbol: 'kr', name: 'Couronne Suédoise', countryCode: 'SE', countryName: 'Suède'),
    'NO': Currency(code: 'NOK', symbol: 'kr', name: 'Couronne Norvégienne', countryCode: 'NO', countryName: 'Norvège'),
    'DK': Currency(code: 'DKK', symbol: 'kr', name: 'Couronne Danoise', countryCode: 'DK', countryName: 'Danemark'),
    'PL': Currency(code: 'PLN', symbol: 'zł', name: 'Zloty Polonais', countryCode: 'PL', countryName: 'Pologne'),
    'CZ': Currency(code: 'CZK', symbol: 'Kč', name: 'Couronne Tchèque', countryCode: 'CZ', countryName: 'République Tchèque'),
    'HU': Currency(code: 'HUF', symbol: 'Ft', name: 'Forint Hongrois', countryCode: 'HU', countryName: 'Hongrie'),
    'RO': Currency(code: 'RON', symbol: 'lei', name: 'Leu Roumain', countryCode: 'RO', countryName: 'Roumanie'),
    'BG': Currency(code: 'BGN', symbol: 'лв', name: 'Lev Bulgare', countryCode: 'BG', countryName: 'Bulgarie'),
    'HR': Currency(code: 'EUR', symbol: '€', name: 'Euro', countryCode: 'HR', countryName: 'Croatie'),
    'TR': Currency(code: 'TRY', symbol: '₺', name: 'Livre Turque', countryCode: 'TR', countryName: 'Turquie'),
    'RU': Currency(code: 'RUB', symbol: '₽', name: 'Rouble Russe', countryCode: 'RU', countryName: 'Russie'),
    'UA': Currency(code: 'UAH', symbol: '₴', name: 'Hryvnia Ukrainienne', countryCode: 'UA', countryName: 'Ukraine'),

    // Amériques
    'US': Currency(code: 'USD', symbol: '\$', name: 'Dollar Américain', countryCode: 'US', countryName: 'États-Unis'),
    'CA': Currency(code: 'CAD', symbol: 'C\$', name: 'Dollar Canadien', countryCode: 'CA', countryName: 'Canada'),
    'MX': Currency(code: 'MXN', symbol: '\$', name: 'Peso Mexicain', countryCode: 'MX', countryName: 'Mexique'),
    'BR': Currency(code: 'BRL', symbol: 'R\$', name: 'Real Brésilien', countryCode: 'BR', countryName: 'Brésil'),
    'AR': Currency(code: 'ARS', symbol: '\$', name: 'Peso Argentin', countryCode: 'AR', countryName: 'Argentine'),
    'CL': Currency(code: 'CLP', symbol: '\$', name: 'Peso Chilien', countryCode: 'CL', countryName: 'Chili'),
    'CO': Currency(code: 'COP', symbol: '\$', name: 'Peso Colombien', countryCode: 'CO', countryName: 'Colombie'),
    'PE': Currency(code: 'PEN', symbol: 'S/', name: 'Sol Péruvien', countryCode: 'PE', countryName: 'Pérou'),
    'UY': Currency(code: 'UYU', symbol: '\$', name: 'Peso Uruguayen', countryCode: 'UY', countryName: 'Uruguay'),

    // Asie-Pacifique
    'JP': Currency(code: 'JPY', symbol: '¥', name: 'Yen Japonais', countryCode: 'JP', countryName: 'Japon'),
    'CN': Currency(code: 'CNY', symbol: '¥', name: 'Yuan Chinois', countryCode: 'CN', countryName: 'Chine'),
    'KR': Currency(code: 'KRW', symbol: '₩', name: 'Won Sud-Coréen', countryCode: 'KR', countryName: 'Corée du Sud'),
    'IN': Currency(code: 'INR', symbol: '₹', name: 'Roupie Indienne', countryCode: 'IN', countryName: 'Inde'),
    'AU': Currency(code: 'AUD', symbol: 'A\$', name: 'Dollar Australien', countryCode: 'AU', countryName: 'Australie'),
    'NZ': Currency(code: 'NZD', symbol: 'NZ\$', name: 'Dollar Néo-Zélandais', countryCode: 'NZ', countryName: 'Nouvelle-Zélande'),
    'SG': Currency(code: 'SGD', symbol: 'S\$', name: 'Dollar de Singapour', countryCode: 'SG', countryName: 'Singapour'),
    'HK': Currency(code: 'HKD', symbol: 'HK\$', name: 'Dollar de Hong Kong', countryCode: 'HK', countryName: 'Hong Kong'),
    'TW': Currency(code: 'TWD', symbol: 'NT\$', name: 'Dollar Taïwanais', countryCode: 'TW', countryName: 'Taïwan'),
    'TH': Currency(code: 'THB', symbol: '฿', name: 'Baht Thaïlandais', countryCode: 'TH', countryName: 'Thaïlande'),
    'MY': Currency(code: 'MYR', symbol: 'RM', name: 'Ringgit Malaisien', countryCode: 'MY', countryName: 'Malaisie'),
    'ID': Currency(code: 'IDR', symbol: 'Rp', name: 'Roupie Indonésienne', countryCode: 'ID', countryName: 'Indonésie'),
    'PH': Currency(code: 'PHP', symbol: '₱', name: 'Peso Philippin', countryCode: 'PH', countryName: 'Philippines'),
    'VN': Currency(code: 'VND', symbol: '₫', name: 'Dong Vietnamien', countryCode: 'VN', countryName: 'Vietnam'),
    'BD': Currency(code: 'BDT', symbol: '৳', name: 'Taka Bangladais', countryCode: 'BD', countryName: 'Bangladesh'),
    'PK': Currency(code: 'PKR', symbol: '₨', name: 'Roupie Pakistanaise', countryCode: 'PK', countryName: 'Pakistan'),
    'LK': Currency(code: 'LKR', symbol: '₨', name: 'Roupie Sri-Lankaise', countryCode: 'LK', countryName: 'Sri Lanka'),

    // Moyen-Orient et Afrique
    'AE': Currency(code: 'AED', symbol: 'د.إ', name: 'Dirham des EAU', countryCode: 'AE', countryName: 'Émirats Arabes Unis'),
    'SA': Currency(code: 'SAR', symbol: '﷼', name: 'Rial Saoudien', countryCode: 'SA', countryName: 'Arabie Saoudite'),
    'QA': Currency(code: 'QAR', symbol: '﷼', name: 'Rial Qatarien', countryCode: 'QA', countryName: 'Qatar'),
    'KW': Currency(code: 'KWD', symbol: 'د.ك', name: 'Dinar Koweïtien', countryCode: 'KW', countryName: 'Koweït'),
    'BH': Currency(code: 'BHD', symbol: '.د.ب', name: 'Dinar Bahreïni', countryCode: 'BH', countryName: 'Bahreïn'),
    'OM': Currency(code: 'OMR', symbol: '﷼', name: 'Rial Omanais', countryCode: 'OM', countryName: 'Oman'),
    'IL': Currency(code: 'ILS', symbol: '₪', name: 'Shekel Israélien', countryCode: 'IL', countryName: 'Israël'),
    'EG': Currency(code: 'EGP', symbol: '£', name: 'Livre Égyptienne', countryCode: 'EG', countryName: 'Égypte'),
    'ZA': Currency(code: 'ZAR', symbol: 'R', name: 'Rand Sud-Africain', countryCode: 'ZA', countryName: 'Afrique du Sud'),
    'NG': Currency(code: 'NGN', symbol: '₦', name: 'Naira Nigérian', countryCode: 'NG', countryName: 'Nigeria'),
    'KE': Currency(code: 'KES', symbol: 'KSh', name: 'Shilling Kényan', countryCode: 'KE', countryName: 'Kenya'),
    'GH': Currency(code: 'GHS', symbol: '₵', name: 'Cedi Ghanéen', countryCode: 'GH', countryName: 'Ghana'),
    'MA': Currency(code: 'MAD', symbol: 'د.م.', name: 'Dirham Marocain', countryCode: 'MA', countryName: 'Maroc'),
    'TN': Currency(code: 'TND', symbol: 'د.ت', name: 'Dinar Tunisien', countryCode: 'TN', countryName: 'Tunisie'),
  };

  // Initialisation du service
  Future<void> initialize() async {
    state = state.copyWith(
      isLoading: true, 
      availableCurrencies: _countryCurrencies.values.toList()
    );
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCurrency = prefs.getString('app_currency');
      
      if (savedCurrency != null) {
        final currency = _countryCurrencies.values.firstWhere(
          (c) => c.code == savedCurrency,
          orElse: () => _countryCurrencies['FR']!,
        );
        
        state = state.copyWith(
          currentCurrency: currency.code,
          currencySymbol: currency.symbol,
          countryCode: currency.countryCode,
          isAutoDetected: false,
        );
      } else {
        await _autoDetectCurrency();
      }
    } catch (e) {
      // Erreur silencieuse, garder EUR par défaut
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // Détecter automatiquement la monnaie selon le pays système
  Future<void> _autoDetectCurrency() async {
    try {
      final systemLocale = Platform.localeName;
      final countryCode = systemLocale.split('_').length > 1 
          ? systemLocale.split('_')[1] 
          : 'FR';
      
      final currency = _countryCurrencies[countryCode] ?? _countryCurrencies['FR']!;
      
      state = state.copyWith(
        currentCurrency: currency.code,
        currencySymbol: currency.symbol,
        countryCode: currency.countryCode,
        isAutoDetected: true,
      );
      
      await _saveCurrency(currency.code);
    } catch (e) {
      // Erreur silencieuse, garder EUR par défaut
    }
  }

  // Détecter monnaie selon la géolocalisation
  Future<void> detectCurrencyFromLocation(String countryName) async {
    try {
      final countryCode = _getCountryCodeFromName(countryName);
      final currency = _countryCurrencies[countryCode] ?? _countryCurrencies['FR']!;
      
      state = state.copyWith(
        currentCurrency: currency.code,
        currencySymbol: currency.symbol,
        countryCode: currency.countryCode,
        isAutoDetected: true,
      );
      
      await _saveCurrency(currency.code);
    } catch (e) {
      // Erreur silencieuse
    }
  }

  // Changer manuellement la monnaie
  Future<void> changeCurrency(String currencyCode) async {
    try {
      final currency = _countryCurrencies.values.firstWhere(
        (c) => c.code == currencyCode,
        orElse: () => _countryCurrencies['FR']!,
      );
      
      state = state.copyWith(
        currentCurrency: currency.code,
        currencySymbol: currency.symbol,
        countryCode: currency.countryCode,
        isAutoDetected: false,
      );
      
      await _saveCurrency(currency.code);
    } catch (e) {
      // Erreur silencieuse
    }
  }

  // Formater un montant avec la monnaie actuelle
  String formatAmount(double amount) {
    final symbol = state.currencySymbol;
    final formattedAmount = amount.toStringAsFixed(2);
    
    // Formatage selon la monnaie et les conventions locales
    switch (state.currentCurrency) {
      // Symbole avant (format américain)
      case 'USD':
      case 'CAD':
      case 'AUD':
      case 'NZD':
      case 'SGD':
      case 'HKD':
      case 'TWD':
      case 'MXN':
      case 'ARS':
      case 'CLP':
      case 'COP':
      case 'BRL':
        return '$symbol$formattedAmount';
      
      // Symbole après avec espace (format européen)
      case 'EUR':
      case 'GBP':
      case 'CHF':
      case 'SEK':
      case 'NOK':
      case 'DKK':
      case 'PLN':
      case 'CZK':
      case 'HUF':
      case 'RON':
      case 'BGN':
        return '$formattedAmount $symbol';
      
      // Symbole avant sans espace (format asiatique)
      case 'JPY':
      case 'CNY':
      case 'KRW':
      case 'INR':
      case 'THB':
      case 'MYR':
      case 'IDR':
      case 'PHP':
      case 'VND':
      case 'BDT':
      case 'PKR':
      case 'LKR':
        return '$symbol$formattedAmount';
      
      // Symbole après (format moyen-oriental/africain)
      case 'AED':
      case 'SAR':
      case 'QAR':
      case 'KWD':
      case 'BHD':
      case 'OMR':
      case 'ILS':
      case 'EGP':
      case 'MAD':
      case 'TND':
        return '$formattedAmount $symbol';
      
      // Format standard pour les autres
      default:
        return '$formattedAmount $symbol';
    }
  }

  // Obtenir les informations d'une monnaie
  Currency? getCurrencyInfo(String currencyCode) {
    try {
      return _countryCurrencies.values.firstWhere(
        (c) => c.code == currencyCode,
      );
    } catch (e) {
      return null;
    }
  }

  // Obtenir la monnaie d'un pays
  Currency? getCurrencyByCountry(String countryCode) {
    return _countryCurrencies[countryCode.toUpperCase()];
  }

  // Obtenir toutes les monnaies disponibles
  List<Currency> getAllCurrencies() {
    return _countryCurrencies.values.toList();
  }

  // Obtenir les monnaies par région
  List<Currency> getCurrenciesByRegion(String region) {
    switch (region.toLowerCase()) {
      case 'europe':
        return _countryCurrencies.values.where((c) => 
          ['FR', 'DE', 'IT', 'ES', 'NL', 'BE', 'AT', 'PT', 'GB', 'CH', 'SE', 'NO', 'DK', 'PL', 'CZ', 'HU', 'RO', 'BG', 'HR', 'TR', 'RU', 'UA'].contains(c.countryCode)
        ).toList();
      
      case 'americas':
        return _countryCurrencies.values.where((c) => 
          ['US', 'CA', 'MX', 'BR', 'AR', 'CL', 'CO', 'PE', 'UY'].contains(c.countryCode)
        ).toList();
      
      case 'asia':
        return _countryCurrencies.values.where((c) => 
          ['JP', 'CN', 'KR', 'IN', 'SG', 'HK', 'TW', 'TH', 'MY', 'ID', 'PH', 'VN', 'BD', 'PK', 'LK'].contains(c.countryCode)
        ).toList();
      
      case 'oceania':
        return _countryCurrencies.values.where((c) => 
          ['AU', 'NZ'].contains(c.countryCode)
        ).toList();
      
      case 'middle_east':
        return _countryCurrencies.values.where((c) => 
          ['AE', 'SA', 'QA', 'KW', 'BH', 'OM', 'IL'].contains(c.countryCode)
        ).toList();
      
      case 'africa':
        return _countryCurrencies.values.where((c) => 
          ['EG', 'ZA', 'NG', 'KE', 'GH', 'MA', 'TN'].contains(c.countryCode)
        ).toList();
      
      default:
        return getAllCurrencies();
    }
  }

  // Rechercher des monnaies
  List<Currency> searchCurrencies(String query) {
    final lowerQuery = query.toLowerCase();
    return _countryCurrencies.values.where((currency) =>
      currency.code.toLowerCase().contains(lowerQuery) ||
      currency.name.toLowerCase().contains(lowerQuery) ||
      currency.countryName.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  // Vérifier si une monnaie est supportée
  bool isCurrencySupported(String currencyCode) {
    return _countryCurrencies.values.any((c) => c.code == currencyCode);
  }

  // Obtenir le taux de change (simulation - à remplacer par une vraie API)
  Future<double> getExchangeRate(String fromCurrency, String toCurrency) async {
    // Simulation de taux de change
    // En production, utilisez une vraie API comme CurrencyAPI, ExchangeRate-API, etc.
    final rates = {
      'EUR_USD': 1.10,
      'USD_EUR': 0.91,
      'EUR_GBP': 0.87,
      'GBP_EUR': 1.15,
      'USD_JPY': 150.0,
      'JPY_USD': 0.0067,
      'EUR_CHF': 0.97,
      'CHF_EUR': 1.03,
    };
    
    final key = '${fromCurrency}_$toCurrency';
    return rates[key] ?? 1.0;
  }

  // Convertir un montant d'une monnaie à une autre
  Future<double> convertAmount(double amount, String fromCurrency, String toCurrency) async {
    if (fromCurrency == toCurrency) return amount;
    
    final rate = await getExchangeRate(fromCurrency, toCurrency);
    return amount * rate;
  }

  // Sauvegarder la monnaie
  Future<void> _saveCurrency(String currencyCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_currency', currencyCode);
    } catch (e) {
      // Erreur silencieuse
    }
  }

  // Convertir nom de pays en code pays
  String _getCountryCodeFromName(String countryName) {
    final countryMappings = {
      // Français
      'France': 'FR',
      'Allemagne': 'DE',
      'Italie': 'IT',
      'Espagne': 'ES',
      'Pays-Bas': 'NL',
      'Belgique': 'BE',
      'Autriche': 'AT',
      'Portugal': 'PT',
      'Royaume-Uni': 'GB',
      'Suisse': 'CH',
      'Suède': 'SE',
      'Norvège': 'NO',
      'Danemark': 'DK',
      'États-Unis': 'US',
      'Canada': 'CA',
      'Mexique': 'MX',
      'Brésil': 'BR',
      'Argentine': 'AR',
      'Chili': 'CL',
      'Colombie': 'CO',
      'Pérou': 'PE',
      'Japon': 'JP',
      'Chine': 'CN',
      'Corée du Sud': 'KR',
      'Inde': 'IN',
      'Australie': 'AU',
      'Nouvelle-Zélande': 'NZ',
      'Singapour': 'SG',
      'Hong Kong': 'HK',
      'Thaïlande': 'TH',
      'Malaisie': 'MY',
      'Indonésie': 'ID',
      'Philippines': 'PH',
      'Vietnam': 'VN',
      
      // Anglais
      'Germany': 'DE',
      'Italy': 'IT',
      'Spain': 'ES',
      'Netherlands': 'NL',
      'Belgium': 'BE',
      'Austria': 'AT',
      'United Kingdom': 'GB',
      'Switzerland': 'CH',
      'Sweden': 'SE',
      'Norway': 'NO',
      'Denmark': 'DK',
      'United States': 'US',
      'Brazil': 'BR',
      'Argentina': 'AR',
      'Chile': 'CL',
      'Colombia': 'CO',
      'Peru': 'PE',
      'Japan': 'JP',
      'China': 'CN',
      'South Korea': 'KR',
      'India': 'IN',
      'Australia': 'AU',
      'New Zealand': 'NZ',
      'Singapore': 'SG',
      'Thailand': 'TH',
      'Malaysia': 'MY',
      'Indonesia': 'ID',
      'Philippines': 'PH',
      'Vietnam': 'VN',
    };
    
    return countryMappings[countryName] ?? 'FR';
  }

  // Réinitialiser aux paramètres par défaut
  Future<void> resetToDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('app_currency');
      await initialize();
    } catch (e) {
      // Erreur silencieuse
    }
  }
}