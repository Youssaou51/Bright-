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
        title: Text('Gérer les Rôles', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 2,
      ),
      body: Container(
        color: Colors.white,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)))
            : _users.isEmpty
            ? const Center(child: Text('Aucun utilisateur trouvé.', style: TextStyle(fontSize: 16, color: Colors.grey)))
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Color(0xFF1976D2).withOpacity(0.1),
                      child: Text(user['username'][0], style: GoogleFonts.poppins(color: Color(0xFF1976D2), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['username'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('Rôle: ${user['role']}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                          Text('Actif: ${user['is_active'] ? 'Oui' : 'Non'}', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: user['role'],
                          items: ['user', 'admin'].map((String role) {
                            return DropdownMenuItem<String>(
                              value: role,
                              child: Text(role, style: GoogleFonts.poppins(fontSize: 14)),
                            );
                          }).toList(),
                          onChanged: (String? newRole) {
                            if (newRole != null && newRole != user['role']) {
                              _updateRole(user['id'], newRole);
                            }
                          },
                          dropdownColor: Colors.white,
                          style: GoogleFonts.poppins(color: Color(0xFF1976D2)),
                          underline: Container(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1976D2)),
                        ),
                        const SizedBox(width: 16),
                        Switch(
                          value: user['is_active'] ?? false,
                          onChanged: (bool newValue) {
                            _toggleActivation(user['id'], newValue);
                          },
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.redAccent,
                          activeTrackColor: Colors.green.withOpacity(0.5),
                          inactiveTrackColor: Colors.redAccent.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}