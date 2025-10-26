// lib/widgets/pro_feature_guard.dart
import 'package:flutter/material.dart';
import '../services/subscription_service.dart';
import '../screens/subscription_screen.dart';

class ProFeatureGuard extends StatelessWidget {
  final Widget child;
  final String featureName;
  final bool showLockIcon;

  const ProFeatureGuard({
    Key? key,
    required this.child,
    required this.featureName,
    this.showLockIcon = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SubscriptionService.isProUser(),
      builder: (context, snapshot) {
        final isPro = snapshot.data ?? false;

        if (isPro) {
          return child;
        }

        // Show locked feature with overlay
        return Stack(
          children: [
            // Blurred/disabled child
            Opacity(
              opacity: 0.5,
              child: AbsorbPointer(
                child: child,
              ),
            ),
            
            // Lock overlay
            Positioned.fill(
              child: InkWell(
                onTap: () {
                  _showProDialog(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showLockIcon)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.lock,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'PRO FEATURE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showProDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.star, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Upgrade to Pro'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock "$featureName" and all premium features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildFeatureItem('📊 Advanced Analytics & Insights'),
            _buildFeatureItem('🎯 AI-Powered Predictions'),
            _buildFeatureItem('📈 Detailed Progress Tracking'),
            _buildFeatureItem('💪 Personalized Training Plans'),
            _buildFeatureItem('🏆 Competition Mode'),
            _buildFeatureItem('☁️ Cloud Backup & Sync'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Maybe Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionScreen(),
                ),
              );
            },
            icon: Icon(Icons.star),
            label: Text('Upgrade Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 20),
          SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}