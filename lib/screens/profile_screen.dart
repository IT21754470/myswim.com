// ignore_for_file: avoid_print, prefer_const_constructors, deprecated_member_use

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/app_logo.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? userProfile;
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      
      setState(() {
        isLoading = true;
        hasError = false;
      });
      
      final profile = await ProfileService.getUserProfile();
      setState(() {
        userProfile = profile;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadUserProfile,
            ),
          ),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      final authService = AuthService();
      await authService.signOut();
      
      // Clear profile data
      await ProfileService.clearUserProfile();
      
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.logout, color: Colors.white),
                SizedBox(width: 12),
                Text('Logged out successfully'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(currentProfile: userProfile),
      ),
    );
    
    if (result == true) {
      _loadUserProfile(); // Reload profile data
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF2A5298),
            ),
            SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: Color(0xFF2A5298),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUserProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A5298),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: const Color(0xFF2A5298),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Profile Header
              _buildProfileHeader(user),
              
              const SizedBox(height: 30),
              
              // Profile Details Card
              _buildProfileDetailsCard(),
              
              const SizedBox(height: 20),
              
              // Swimming Stats Card
              _buildStatsCard(),
              
              const SizedBox(height: 30),
              
              // Edit Profile Button
              _buildEditProfileButton(),
              
              const SizedBox(height: 20),
              
              // Logout Button
              _buildLogoutButton(),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildProfileImage(String? imageUrl, {double size = 120}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return _buildDefaultAvatar(size);
  }

  // Check if it's a base64 image (starts with data:image/)
  if (imageUrl.startsWith('data:image/')) {
    try {
      // Extract base64 data after the comma
      final base64String = imageUrl.split(',')[1];
      final Uint8List bytes = base64Decode(base64String);
      
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Error displaying base64 image: $error');
            return _buildDefaultAvatar(size);
          },
        ),
      );
    } catch (e) {
      print('❌ Error decoding base64 image: $e');
      return _buildDefaultAvatar(size);
    }
  } else {
    // Legacy network image (if you had any before)
    return ClipOval(
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
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
          print('❌ Error loading network image: $error');
          return _buildDefaultAvatar(size);
        },
      ),
    );
  }
}

Widget _buildDefaultAvatar(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [Color(0xFF2A5298), Color(0xFF667eea)],
      ),
    ),
    child: Icon(
      Icons.person,
      color: Colors.white,
      size: size * 0.4,
    ),
  );
}
Widget _buildProfileHeader(User? user) {
  return Column(
    children: [
      // Profile Avatar with Upload Indicator
      Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF2A5298), Color(0xFF667eea)],
              ),
            ),
            // ✅ Replace the CircleAvatar with your helper method
            child: userProfile?.profileImageUrl != null
                ? _buildProfileImage(userProfile!.profileImageUrl!, size: 120) // Use your helper
                : const AppLogo(size: 120, showShadow: true),
          ),
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF2A5298),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_upload,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
      
      const SizedBox(height: 16),
      
      // Rest of your header code stays the same...
      Text(
        userProfile?.name ?? user?.displayName ?? 'Swimmer',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2A5298),
        ),
      ),
      // ... rest of the method
    ],
  );
}

  Widget _buildProfileDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profile Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2A5298),
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Age',
                  userProfile?.age?.toString() ?? 'Not set',
                  Icons.cake_outlined,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Gender',
                  userProfile?.gender ?? 'Not set',
                  Icons.person_outline,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  'Weight',
                  userProfile?.weight != null ? '${userProfile!.weight} kg' : 'Not set',
                  Icons.fitness_center_outlined,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  'Style',
                  userProfile?.favoriteStyle ?? 'Not set',
                  Icons.pool_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2A5298).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2A5298),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2A5298),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Swimming Stats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2A5298),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('Sessions', userProfile?.totalSessions ?? 0),
              _buildStatItem('Distance', '${userProfile?.totalDistance ?? 0} km'),
              _buildStatItem('Hours', userProfile?.totalHours ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2A5298),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEditProfileButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A5298), Color(0xFF667eea)],
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
      child: ElevatedButton.icon(
        onPressed: _navigateToEditProfile,
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text(
          'Edit Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade400, Colors.red.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => _signOut(context),
        icon: const Icon(Icons.logout, color: Colors.white),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}