import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Import intl for NumberFormat
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';

class FoundationAmountWidget extends StatefulWidget {
  final SupabaseClient supabase;
  final double initialAmount;
  final Function(double) onAmountUpdated;

  const FoundationAmountWidget({
    Key? key,
    required this.supabase,
    required this.initialAmount,
    required this.onAmountUpdated,
  }) : super(key: key);

  @override
  State<FoundationAmountWidget> createState() => _FoundationAmountWidgetState();
}

class _FoundationAmountWidgetState extends State<FoundationAmountWidget> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAmount();
  }

  Future<void> _loadAmount() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final response = await widget.supabase
          .from('funds')
          .select('amount')
          .eq('id', 'foundation-funds')
          .single();
      if (kDebugMode) dev.log('Funds response: $response');
      final amount = (response['amount'] as num?)?.toDouble() ?? widget.initialAmount;
      widget.onAmountUpdated(amount);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) dev.log('Error loading funds: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      dev.log('Rendering: loading=$_isLoading, initialAmount=${widget.initialAmount}, error=$_errorMessage');
    }
    // Format the amount with thousand separators and CFA symbol
    final numberFormat = NumberFormat.currency(
      locale: 'fr_XO', // French locale for West Africa (XOF)
      symbol: 'CFA',
      decimalDigits: 2, // Two decimal places
    );
    final formattedAmount = numberFormat.format(widget.initialAmount);

    return SizedBox(
      height: 30,
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : Marquee(
        text: _errorMessage != null
            ? '💰 Fonds non disponibles : $_errorMessage'
            : '💰 Fonds disponibles : $formattedAmount',
        style: GoogleFonts.poppins(
          color: Colors.blueAccent,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        blankSpace: 20.0,
        velocity: 50.0,
        pauseAfterRound: Duration(seconds: 1),
      ),
    );
  }
}