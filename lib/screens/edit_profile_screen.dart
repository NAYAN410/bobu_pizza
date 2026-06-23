import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await SupabaseService.getProfile();
    final userEmail = SupabaseService.client.auth.currentUser?.email;
    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile['full_name'] ?? '';
        _phoneController.text = profile['phone'] ?? '';
        _emailController.text = userEmail ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await SupabaseService.updateProfile({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Edit Profile', 
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          )),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildTextField(_nameController, 'Full Name', Icons.person_outline, isDark),
                  const SizedBox(height: 16),
                  _buildTextField(_emailController, 'Email Address (Non-editable)', Icons.email_outlined, isDark, readOnly: true),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'Phone Number', Icons.phone_outlined, isDark, keyboardType: TextInputType.phone),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24, 
                              width: 24, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : Text('Save Changes', 
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark, {int maxLines = 1, TextInputType? keyboardType, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, 
          style: GoogleFonts.poppins(
            fontSize: 14, 
            fontWeight: FontWeight.w600, 
            color: isDark ? Colors.white70 : Colors.grey[700]
          )),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: readOnly 
                ? (isDark ? Colors.white38 : Colors.grey[600])
                : (isDark ? Colors.white : Colors.black),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: readOnly ? Colors.grey : AppColors.primary, size: 22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12), 
              borderSide: BorderSide(color: readOnly ? (isDark ? Colors.white10 : Colors.grey.shade300) : AppColors.primary, width: 1.5)
            ),
            filled: true,
            fillColor: readOnly 
                ? (isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade100)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
            hintStyle: GoogleFonts.poppins(color: isDark ? Colors.white24 : Colors.grey),
          ),
        ),
      ],
    );
  }
}
