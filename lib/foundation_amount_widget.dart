import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
    setState(() => _isLoading = true);

    try {
      final response = await widget.supabase
          .from('funds')
          .select('amount')
          .eq('id', 'foundation-funds')
          .single();

      final amount = (response['amount'] as num?)?.toDouble() ?? widget.initialAmount;
      widget.onAmountUpdated(amount);
    } catch (e) {
      print('Error loading funds: $e'); // pour debug seulement
      setState(() {
        _errorMessage = 'Failed to load funds.'; // message court pour l’utilisateur
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    print('Rendering: loading=$_isLoading, initialAmount=${widget.initialAmount}, error=$_errorMessage');
    final numberFormat = NumberFormat.currency(
      locale: 'fr_XO',
      symbol: 'CFA',
      decimalDigits: 2,
    );
    final formattedAmount = numberFormat.format(widget.initialAmount);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
          : Marquee(
        text: _errorMessage != null
            ? '💰 Fonds non disponibles : $_errorMessage'
            : '💰 Fonds disponibles : $formattedAmount',
        style: GoogleFonts.poppins(
          color: Color(0xFF1976D2),
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        scrollAxis: Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.center,
        blankSpace: 20.0,
        velocity: 50.0,
        pauseAfterRound: const Duration(seconds: 1),
      ),
    );
  }
}