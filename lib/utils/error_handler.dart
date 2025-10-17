import 'dart:io';
import 'dart:async'; // ✅ Nécessaire pour TimeoutException
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ErrorHandler {
  /// 🔄 Écran de chargement (spinnner central)
  static Widget buildLoadingScreen() {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF1976D2),
      ),
    );
  }

  /// ❌ Écran d’erreur avec message
  static Widget buildErrorScreen(String message) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.poppins(
          color: Colors.red,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// 📢 SnackBar d’erreur
  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ✅ SnackBar de succès
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ⚙️ Gestion centralisée des exceptions (réseau / Supabase / inconnues)
  static void handleException(BuildContext context, dynamic error) {
    String message = "Une erreur inattendue est survenue.";

    if (error is SocketException) {
      message = "Erreur de connexion Internet. Vérifie ta connexion.";
    } else if (error is TimeoutException) {
      message = "Le serveur met trop de temps à répondre.";
    } else if (error is PostgrestException) {
      message = "Erreur de base de données : ${error.message}";
    } else if (error is AuthException) {
      message = "Erreur d’authentification : ${error.message}";
    } else if (error.toString().contains('SupabaseException')) {
      message = "Erreur Supabase détectée.";
    } else {
      message = error.toString();
    }

    showError(context, message);
  }

  /// 🧪 Vérifie la connexion Internet avant une requête
  static Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }

  /// 🌐 Exécute une opération avec gestion automatique des erreurs
  static Future<T?> runWithHandler<T>(
      BuildContext context,
      Future<T> Function() operation, {
        String? successMessage,
      }) async {
    try {
      final result = await operation();

      if (successMessage != null) {
        showSuccess(context, successMessage);
      }

      return result;
    } catch (error) {
      handleException(context, error);
      return null;
    }
  }
}
