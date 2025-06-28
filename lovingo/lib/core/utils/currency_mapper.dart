class CurrencyMapper {
  static const Map<String, Map<String, String>> _currencyMap = {
    // Europe
    'FR': {'code': 'EUR', 'symbol': '€'},
    'DE': {'code': 'EUR', 'symbol': '€'},
    'IT': {'code': 'EUR', 'symbol': '€'},
    'ES': {'code': 'EUR', 'symbol': '€'},
    'NL': {'code': 'EUR', 'symbol': '€'},
    
    // Amérique du Nord
    'US': {'code': 'USD', 'symbol': r'$'},
    'CA': {'code': 'CAD', 'symbol': r'C$'},
    
    // Royaume-Uni
    'GB': {'code': 'GBP', 'symbol': '£'},
    
    // Asie
    'JP': {'code': 'JPY', 'symbol': '¥'},
    'CN': {'code': 'CNY', 'symbol': '¥'},
    'KR': {'code': 'KRW', 'symbol': '₩'},
    'IN': {'code': 'INR', 'symbol': '₹'},
    
    // Océanie
    'AU': {'code': 'AUD', 'symbol': r'A$'},
    'NZ': {'code': 'NZD', 'symbol': r'NZ$'},
    
    // Suisse
    'CH': {'code': 'CHF', 'symbol': 'CHF'},
    
    // Scandinavie
    'SE': {'code': 'SEK', 'symbol': 'kr'},
    'NO': {'code': 'NOK', 'symbol': 'kr'},
    'DK': {'code': 'DKK', 'symbol': 'kr'},
  };

  static Map<String, String> getCurrencyForCountry(String countryCode) {
    return _currencyMap[countryCode] ?? {'code': 'USD', 'symbol': r'$'};
  }

  static List<String> getSupportedCountries() {
    return _currencyMap.keys.toList();
  }

  static List<String> getSupportedCurrencies() {
    return _currencyMap.values
        .map((currency) => currency['code']!)
        .toSet()
        .toList();
  }
}
