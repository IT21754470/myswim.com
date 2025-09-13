// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Account'),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSettingItem(
                'Edit Profile',
                'Update your personal information',
                Icons.person_outline,
                () {},
              ),
              _buildSettingItem(
                'Privacy Settings',
                'Manage your privacy preferences',
                Icons.privacy_tip_outlined,
                () {},
              ),
              _buildSettingItem(
                'Notifications',
                'Configure notification preferences',
                Icons.notifications_outlined,
                () {},
              ),
            ]),
            
            const SizedBox(height: 24),
            _buildSectionHeader('App Settings'),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSettingItem(
                'Units',
                'Distance, time, and measurement units',
                Icons.straighten,
                () {},
              ),
              _buildSettingItem(
                'Theme',
                'Choose your preferred theme',
                Icons.palette_outlined,
                () {},
              ),
              _buildSettingItem(
                'Data Sync',
                'Backup and sync your data',
                Icons.sync,
                () {},
              ),
            ]),
            
            const SizedBox(height: 24),
            _buildSectionHeader('Support'),
            const SizedBox(height: 12),
            _buildSettingsGroup([
              _buildSettingItem(
                'Help & FAQ',
                'Get help and find answers',
                Icons.help_outline,
                () {},
              ),
              _buildSettingItem(
                'Contact Us',
                'Send feedback or report issues',
                Icons.contact_support_outlined,
                () {},
              ),
              _buildSettingItem(
                'About',
                'App version and information',
                Icons.info_outline,
                () {},
              ),
            ]),
            
            const SizedBox(height: 32),
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E3C72),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items,
      ),
    );
  }

  Widget _buildSettingItem(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A5298).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2A5298),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 8),
            Text(
              'Sign Out',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}