import 'package:flutter/material.dart';
import 'dart:io';

Future<T?> runNetworkCall<T>({
  required BuildContext context,
  required Future<T> Function() networkCall,
  String? errorMessage,
}) async {
  try {
    return await networkCall();
  } on SocketException {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage ?? 'Aucune connexion Internet.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return null;
  } catch (_) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage ?? 'Une erreur est survenue. Veuillez réessayer.'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return null;
  }
}
