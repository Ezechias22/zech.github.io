// lib/core/utils/global_keys.dart
import 'package:flutter/material.dart';

// ============================================
// 🌐 CLÉS DE NAVIGATION GLOBALES
// ============================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Méthodes utilitaires pour la navigation
class NavigationUtils {
  static NavigatorState? get navigator => navigatorKey.currentState;
  static BuildContext? get context => navigatorKey.currentContext;
  
  // Navigation sécurisée
  static Future<T?> pushNamed<T extends Object?>(String routeName, {Object? arguments}) {
    return navigator?.pushNamed<T>(routeName, arguments: arguments) ?? Future.value(null);
  }
  
  static void pop<T extends Object?>([T? result]) {
    navigator?.pop<T>(result);
  }
  
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) {
    return navigator?.pushReplacementNamed<T, TO>(
      routeName,
      result: result,
      arguments: arguments,
    ) ?? Future.value(null);
  }
  
  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String newRouteName,
    bool Function(Route<dynamic>) predicate, {
    Object? arguments,
  }) {
    return navigator?.pushNamedAndRemoveUntil<T>(
      newRouteName,
      predicate,
      arguments: arguments,
    ) ?? Future.value(null);
  }
  
  // Vérifier si on peut naviguer
  static bool get canNavigate => navigator != null && context != null;
}