import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class FoundationAmountWidget extends StatefulWidget {
  final SupabaseClient supabase;
  final String updatedBy;

  FoundationAmountWidget({required this.supabase, required this.updatedBy});

  @override
  _FoundationAmountWidgetState createState() => _FoundationAmountWidgetState();
}

class _FoundationAmountWidgetState extends State<FoundationAmountWidget> {
  double? _amount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAmount();
  }

  Future<void> _loadAmount() async {
    try {
      final response = await widget.supabase
          .from('funds')
          .select('amount')
          .eq('id', 'foundation-funds')
          .single();

      setState(() {
        _amount = response['amount']; // response is a Map<String, dynamic>
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _amount = null;
        _loading = false;
      });
      // Optionally handle or log the error here
      print('Error loading amount: $error');
    }
  }

  void _showAmountUpdateDialog() {
    double newAmount = _amount ?? 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Modifier le montant"),
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: "Nouveau montant"),
            onChanged: (value) {
              newAmount = double.tryParse(value) ?? newAmount;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _updateAmount(newAmount);
              },
              child: Text("Valider"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Annuler"),
            ),
          ],
        );
      },
    );
  }



  Future<void> _updateAmount(double newAmount) async {
    try {
      final response = await widget.supabase
          .from('funds')
          .update({
        'amount': newAmount,
        'updated_by': widget.updatedBy,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', 'foundation-funds')
          .select()
          .single();

      // Si on arrive ici sans exception, c’est que c’est ok
      setState(() {
        _amount = newAmount;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Montant mis à jour avec succès !")),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur mise à jour: $error")),
      );
    }
  }


  void _showUpdateDialog() {
    final _controller = TextEditingController(text: _amount?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Modifier le montant de la fondation'),
          content: TextField(
            controller: _controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: "Nouveau montant"),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Annuler")),
            TextButton(
              onPressed: () {
                final enteredAmount = double.tryParse(_controller.text);
                if (enteredAmount != null && enteredAmount >= 0) {
                  _updateAmount(enteredAmount);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Veuillez entrer un montant valide")));
                }
              },
              child: Text("Mettre à jour"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return CircularProgressIndicator();

    return GestureDetector(
      onTap: _showUpdateDialog,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10)),
        child: Text(
          _amount == null
              ? "Montant non disponible"
              : "Fondation disponible: \$${_amount!.toStringAsFixed(2)}",
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue[900]),
        ),
      ),
    );
  }
}
