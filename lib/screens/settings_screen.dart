import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
//import 'package:url_launcher/url_launcher.dart';
import '../services/feedback_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Apply gradient background like other screens
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withOpacity(0.95),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold transparent to show gradient
        // Remove the appbar and make everything scrollable
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button and header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
                  child: Row(
                    children: [
                      // Back button
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      
                      // Title
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 20, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),
                      
                      // Empty space to balance the back button
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                
                // Appearance Card with enhanced styling
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSettingsCard(
                    context,
                    title: 'Appearance',
                    icon: Icons.palette_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    children: [
                      _buildSwitchTile(
                        context,
                        title: 'Dark Mode',
                        icon: Icons.dark_mode_rounded,
                        subtitle: 'Toggle between light and dark theme',
                        trailing: Consumer<ThemeProvider>(
                          builder: (context, themeProvider, child) {
                            return Switch(
                              value: themeProvider.isDarkMode,
                              onChanged: (_) => themeProvider.toggleTheme(),
                              activeColor: Theme.of(context).colorScheme.primary,
                              activeTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Notifications Card with enhanced styling
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _buildSettingsCard(
                    context,
                    title: 'Notifications',
                    icon: Icons.notifications_rounded,
                    iconColor: Colors.amber,
                    children: [
                      _buildDisabledTile(
                        context,
                        title: 'Push Notifications',
                        icon: Icons.notifications_active_rounded,
                        subtitle: 'Coming Soon',
                      ),
                      _buildDivider(context),
                      _buildDisabledTile(
                        context,
                        title: 'Email Notifications',
                        icon: Icons.email_rounded,
                        subtitle: 'Coming Soon',
                      ),
                    ],
                  ),
                ),
                
                // About Card with enhanced styling
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: _buildSettingsCard(
                    context,
                    title: 'About',
                    icon: Icons.info_rounded,
                    iconColor: Colors.blue,
                    children: [
                      _buildInfoTile(
                        context,
                        title: 'Version',
                        icon: Icons.tag_rounded,
                        content: FutureBuilder<PackageInfo>(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            final version = snapshot.hasData ? snapshot.data!.version : '';
                            final buildNumber = snapshot.hasData ? snapshot.data!.buildNumber : '';
                            return Text(
                              'v$version ($buildNumber)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // About Card with enhanced styling
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: const Text('Feedback'),
                          leading: Icon(
                            Icons.feedback_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          subtitle: const Text('Help us improve Chrono'),
                          onTap: () {
                            _showFeedbackDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build setting cards with gradient headers
  Widget _buildSettingsCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header with icon and title
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.15),
                  iconColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // List of settings items
          ...children,
        ],
      ),
    );
  }

  // Helper method to build switch tile
  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  // Helper method to build info tile
  Widget _buildInfoTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Widget content,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: content,
        ),
      ),
    );
  }

  // Helper method to build disabled tile
  Widget _buildDisabledTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String subtitle,
  }) {
    return Opacity(
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.grey,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build divider
  Widget _buildDivider(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.1),
        height: 1,
      ),
    );
  }

  // Show feedback dialog with improved UX
  void _showFeedbackDialog(BuildContext context) {
    final feedbackService = FeedbackService();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    // Pre-fill with user data if available
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      nameController.text = user.displayName ?? '';
      emailController.text = user.email ?? '';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.feedback_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Send Feedback')
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We appreciate your feedback to help improve Chrono!',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isSubmitting,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Your Feedback',
                      hintText: 'Tell us what you think or suggest improvements...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your feedback';
                      }
                      return null;
                    },
                    enabled: !isSubmitting,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSubmitting 
                ? null 
                : () async {
                  if (formKey.currentState!.validate()) {
                    setState(() => isSubmitting = true);
                    
                    try {
                      await feedbackService.sendFeedback(
                        message: messageController.text,
                        name: nameController.text,
                        email: emailController.text,
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close feedback dialog
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text('Thank you for your feedback!'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() => isSubmitting = false);
                      
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Error: ${e.toString()}'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSubmitting) ...[
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(isSubmitting ? 'Sending...' : 'Send'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
