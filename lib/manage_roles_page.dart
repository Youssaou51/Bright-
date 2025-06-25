import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class ManageRolesPage extends StatefulWidget {
  final SupabaseClient supabase;

  const ManageRolesPage({Key? key, required this.supabase}) : super(key: key);

  @override
  State<ManageRolesPage> createState() => _ManageRolesPageState();
}

class _ManageRolesPageState extends State<ManageRolesPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final response = await widget.supabase
          .from('users')
          .select('id, username, role, is_active')
          .order('username', ascending: true);
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des utilisateurs: $e')),
      );
    }
  }

  Future<void> _toggleActivation(String userId, bool isActive) async {
    try {
      await widget.supabase
          .from('users')
          .update({'is_active': isActive})
          .eq('id', userId);
      setState(() {
        final userIndex = _users.indexWhere((user) => user['id'] == userId);
        if (userIndex != -1) {
          _users[userIndex]['is_active'] = isActive;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isActive ? 'Utilisateur activé' : 'Utilisateur désactivé')),
      );
    } catch (e) {
      print('Error toggling activation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour de l\'activation: $e')),
      );
    }
  }


  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await widget.supabase
          .from('users')
          .update({'role': newRole})
          .eq('id', userId);
      setState(() {
        final userIndex = _users.indexWhere((user) => user['id'] == userId);
        if (userIndex != -1) {
          _users[userIndex]['role'] = newRole;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rôle mis à jour avec succès !')),
      );
    } catch (e) {
      print('Error updating role: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la mise à jour du rôle: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gérer les Rôles', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(child: Text(user['username'][0])),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['username'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                            Text('Rôle: ${user['role']}', style: GoogleFonts.poppins(fontSize: 13)),
                            Text('Actif: ${user['is_active'] ? 'Oui' : 'Non'}', style: GoogleFonts.poppins(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      DropdownButton<String>(
                        value: user['role'],
                        items: ['user', 'admin'].map((String role) {
                          return DropdownMenuItem<String>(
                            value: role,
                            child: Text(role, style: GoogleFonts.poppins(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (String? newRole) {
                          if (newRole != null && newRole != user['role']) {
                            _updateRole(user['id'], newRole);
                          }
                        },
                      ),
                      Row(
                        children: [
                          Text('Activer', style: GoogleFonts.poppins(fontSize: 13)),
                          Switch(
                            value: user['is_active'] ?? false,
                            onChanged: (bool newValue) {
                              _toggleActivation(user['id'], newValue);
                            },
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );


        },
      ),
    );
  }
}