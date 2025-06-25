import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile? currentProfile;

  const EditProfileScreen({super.key, this.currentProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  
  String? _selectedGender;
  String? _selectedStyle;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isUploadingImage = false;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _swimmingStyles = [
    'Freestyle',
    'Backstroke',
    'Breaststroke',
    'Butterfly',
    'Individual Medley',
    'Open Water'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    if (widget.currentProfile != null) {
      _nameController.text = widget.currentProfile!.name ?? '';
      _ageController.text = widget.currentProfile!.age?.toString() ?? '';
      _weightController.text = widget.currentProfile!.weight?.toString() ?? '';
      _selectedGender = widget.currentProfile!.gender;
      _selectedStyle = widget.currentProfile!.favoriteStyle;
    }
  }

Future<void> _pickImage() async {
  try {
    // Test if Firestore is properly set up (instead of Storage)
    print('🧪 Testing Firestore setup...');
    final isFirestoreSetup = await ProfileService.testFirebaseSetup();
    
    if (!isFirestoreSetup) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firestore is not properly configured. Please check Firebase Console.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,  // Smaller size for base64 storage
      maxHeight: 512,
      imageQuality: 70, // Lower quality to reduce file size
    );

    if (pickedFile != null) {
      final file = File(pickedFile.path);
      
      // Check if file exists
      if (!await file.exists()) {
        throw Exception('Selected file does not exist');
      }
      
      // Check file size before processing
      final fileSize = await file.length();
      if (fileSize > 1 * 1024 * 1024) {  // 1MB limit for base64
        throw Exception('Image too large. Please select an image under 1MB.');
      }
      
      setState(() {
        _selectedImage = file;
      });
      
      print('✅ Image selected: ${pickedFile.path}');
    }
  } catch (e) {
    print('❌ Error picking image: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Error selecting image:'),
              Text('$e', style: const TextStyle(fontSize: 12)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl = widget.currentProfile?.profileImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });

        // Delete old image if exists
        if (widget.currentProfile?.profileImageUrl != null) {
          try {
            await ProfileService.deleteProfileImage(
              widget.currentProfile!.profileImageUrl!
            );
          } catch (e) {
            print('Warning: Could not delete old image: $e');
          }
        }

        // Upload new image
        imageUrl = await ProfileService.uploadProfileImage(_selectedImage!);
        
        setState(() {
          _isUploadingImage = false;
        });
      }

      // Create updated profile
      final updatedProfile = UserProfile(
        name: _nameController.text.trim(),
        age: int.tryParse(_ageController.text.trim()),
        gender: _selectedGender,
        weight: double.tryParse(_weightController.text.trim()),
        favoriteStyle: _selectedStyle,
        profileImageUrl: imageUrl,
        totalSessions: widget.currentProfile?.totalSessions ?? 0,
        totalDistance: widget.currentProfile?.totalDistance ?? 0.0,
        totalHours: widget.currentProfile?.totalHours ?? 0,
        createdAt: widget.currentProfile?.createdAt,
      );

      // Save to Firebase Firestore
      await ProfileService.saveUserProfile(updatedProfile);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cloud_done, color: Colors.white),
                SizedBox(width: 12),
                Text('Profile saved to cloud successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        
        // Return to profile screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Error saving profile'),
                Text(
                  '$e',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _isUploadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2A5298),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: (_isLoading || _isUploadingImage) ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Image Section
              _buildImageSection(),
              
              const SizedBox(height: 32),
              
              // Personal Information
              _buildSectionHeader('Personal Information'),
              const SizedBox(height: 16),
              _buildPersonalInfoFields(),
              
              const SizedBox(height: 32),
              
              // Swimming Information
              _buildSectionHeader('Swimming Information'),
              const SizedBox(height: 16),
              _buildSwimmingInfoFields(),
              
              const SizedBox(height: 40),
              
              // Save Button
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildImageSection() {
  return Column(
    children: [
      GestureDetector(
        onTap: (_isLoading || _isUploadingImage) ? null : _pickImage,
        child: Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2A5298),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: _selectedImage != null
                    ? Image.file(
                        _selectedImage!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                    : widget.currentProfile?.profileImageUrl != null
                        ? _buildProfileImage(widget.currentProfile!.profileImageUrl!)
                        : _buildDefaultAvatar(),
              ),
            ),
            
            // Loading overlay for image upload
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      
      const SizedBox(height: 12),
      GestureDetector(
        onTap: (_isLoading || _isUploadingImage) ? null : _pickImage,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A5298).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF2A5298).withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isUploadingImage ? Icons.cloud_upload : Icons.upload,
                color: const Color(0xFF2A5298),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _isUploadingImage ? 'Processing...' : 'Upload Photo',
                style: const TextStyle(
                  color: Color(0xFF2A5298),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      
      // Firestore indicator
      if (widget.currentProfile?.profileImageUrl != null && _selectedImage == null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_done,
                color: Colors.green,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'Stored in database',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

// Helper method to display base64 or network images
Widget _buildProfileImage(String imageUrl) {
  if (ProfileService.isBase64Image(imageUrl)) {
    // It's a base64 image
    try {
      final base64String = imageUrl.split(',')[1]; // Remove data:image/jpeg;base64, prefix
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    } catch (e) {
      print('❌ Error displaying base64 image: $e');
      return _buildDefaultAvatar();
    }
  } else {
    // It's a network image (legacy)
    return Image.network(
      imageUrl,
      width: 120,
      height: 120,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
            color: const Color(0xFF2A5298),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _buildDefaultAvatar();
      },
    );
  }
}

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A5298), Color(0xFF667eea)],
        ),
      ),
      child: const Icon(
        Icons.person,
        color: Colors.white,
        size: 50,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2A5298),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoFields() {
    return Column(
      children: [
        // Name Field
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Age and Gender Row
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _ageController,
                label: 'Age',
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null || age < 1 || age > 120) {
                      return 'Enter valid age';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDropdownField(
                value: _selectedGender,
                items: _genders,
                label: 'Gender',
                icon: Icons.person_outline,
                onChanged: (value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSwimmingInfoFields() {
    return Column(
      children: [
        // Weight Field
        _buildTextField(
          controller: _weightController,
          label: 'Weight (kg)',
          icon: Icons.fitness_center_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              final weight = double.tryParse(value);
              if (weight == null || weight < 1 || weight > 500) {
                return 'Enter valid weight';
              }
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        // Favorite Swimming Style
        _buildDropdownField(
          value: _selectedStyle,
          items: _swimmingStyles,
          label: 'Favorite Swimming Style',
          icon: Icons.pool_outlined,
          onChanged: (value) {
            setState(() {
              _selectedStyle = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      enabled: !_isLoading && !_isUploadingImage,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2A5298)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A5298), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required List<String> items,
    required String label,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (_isLoading || _isUploadingImage) ? null : onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF2A5298)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2A5298), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: (_isLoading || _isUploadingImage)
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [const Color(0xFF2A5298), const Color(0xFF667eea)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A5298).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_isLoading || _isUploadingImage) ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: (_isLoading || _isUploadingImage)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isUploadingImage ? 'Uploading image...' : 'Saving profile...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Save to Cloud',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}