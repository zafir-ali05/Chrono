import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_screen.dart';
import '../utils/snackbar_utils.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';

class ProfileScreen extends StatefulWidget {
  final bool? initialIsSignUp;

  const ProfileScreen({
    super.key, 
    this.initialIsSignUp,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String error = '';

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                obscureText: true,
              ),
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (newPasswordController.text != confirmPasswordController.text) {
                  setState(() {
                    error = 'New passwords do not match';
                  });
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  setState(() {
                    error = 'Password must be at least 6 characters';
                  });
                  return;
                }
                try {
                  await _auth.changePassword(
                    currentPasswordController.text,
                    newPasswordController.text,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    SnackBarUtils.showAwesomeSnackBar(
                      context: context,
                      title: 'Password Updated',
                      message: 'Your password has been changed successfully!',
                      contentType: ContentType.success,
                    );
                  }
                } catch (e) {
                  setState(() {
                    error = e.toString();
                  });
                }
              },
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImageFromSource(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  child: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImageFromSource(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadImageFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (pickedFile == null) return;
      
      setState(() {
        _isUploading = true;
      });
      
      // Upload image to Firebase Storage
      final imageFile = File(pickedFile.path);
      final downloadUrl = await _storageService.uploadProfileImage(imageFile);
      
      if (downloadUrl != null) {
        // Update profile with new image URL
        await _auth.updateProfile(photoURL: downloadUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
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
        // Remove the AppBar completely
        body: CustomScrollView(
          // Add top padding of 72 pixels to match other screens
          slivers: [
            // Add a SliverAppBar that scrolls with content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 72, 16, 8),
                child: SizedBox(
                  height: 45, // Explicit height to match button height
                  child: Stack(
                    clipBehavior: Clip.none, // Prevent clipping of children
                    children: [
                      // Centered container for the title
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 28,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      
                      // Absolutely positioned settings button
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                  Theme.of(context).colorScheme.primary,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.settings,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Add the profile content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildProfileContent(user),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Move the profile content to a separate method
  Widget _buildProfileContent(User user) {
    // Extract initials for avatar
    final String initials = _getInitials(user);
    
    // Generate a gradient based on the user's display name/email
    final int nameHash = (user.displayName ?? user.email ?? '').hashCode;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    
    // Create a more personalized gradient for the avatar
    final LinearGradient avatarGradient = LinearGradient(
      colors: [
        HSLColor.fromColor(primaryColor).withLightness(0.6).toColor(),
        HSLColor.fromColor(primaryColor).withLightness(0.4).toColor(),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        // Enhanced profile header with gradient and shadow - centered
        Container(
          width: double.infinity, // Make sure this takes full width
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.7),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Ensure all items are centered
            mainAxisAlignment: MainAxisAlignment.center, // Vertically center as well
            children: [
              // Avatar with gradient background and edit button
              Center( // Explicitly center the avatar
                child: Stack(
                  children: [
                    // The avatar/profile image
                    GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        width: 120, // Slightly larger size
                        height: 120, // Slightly larger size
                        decoration: BoxDecoration(
                          gradient: avatarGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isUploading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : ClipOval(
                                child: user.photoURL != null
                                    ? CachedNetworkImage(
                                        imageUrl: user.photoURL!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              fontSize: 42,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Center(
                                          child: Text(
                                            initials,
                                            style: const TextStyle(
                                              fontSize: 42,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          initials,
                                          style: const TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                              ),
                      ),
                    ),
                    // Edit button positioned at bottom-right
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: _showImageSourceDialog,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20), // More space
              // Display name with enhanced styling - centered width
              if (user.displayName?.isNotEmpty ?? false)
                SizedBox(
                  width: double.infinity, // Make this take full width
                  child: Text(
                    user.displayName!,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Show email with subtle styling
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity, // Make this take full width
                child: Text(
                  user.email ?? 'No email',
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
        
        // Rest of the profile content remains the same
        const SizedBox(height: 24),
        
        // Account Information Card with enhanced styling
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
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
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Account Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Account details in styled list tiles
              if (user.displayName?.isNotEmpty ?? false) ...[
                _buildInfoTile(
                  context,
                  label: 'Name',
                  value: user.displayName!,
                  icon: Icons.badge_rounded,
                ),
                _buildDivider(),
              ],
              _buildInfoTile(
                context,
                label: 'Email',
                value: user.email ?? 'No email',
                icon: Icons.email_rounded,
              ),
              _buildDivider(),
              InkWell(
                onTap: () => _showChangePasswordDialog(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Row(
                            children: [
                              Text(
                                '••••••••',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Sign out button with gradient and rounded corners
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red.shade400,
                Colors.red.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade300.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _auth.signOut,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // App info section with subtle styling
        const SizedBox(height: 40),
        // Center(
        //   child: Container(
        //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //     decoration: BoxDecoration(
        //       color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        //       borderRadius: BorderRadius.circular(16),
        //     ),
        //     child: const Column(
        //       children: [
        //         Text(
        //           'Chrono',
        //           style: TextStyle(
        //             fontSize: 14,
        //             fontWeight: FontWeight.w500,
        //           ),
        //         ),
        //         Text(
        //           'Version 1.0.0',
        //           style: TextStyle(
        //             fontSize: 12,
        //             color: Colors.grey,
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInfoTile(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.1),
        height: 1,
      ),
    );
  }

  String _getInitials(User user) {
    if (user.displayName?.isNotEmpty ?? false) {
      final names = user.displayName!.split(' ');
      if (names.length >= 2) {
        return '${names[0][0]}${names[1][0]}'.toUpperCase();
      }
      return user.displayName![0].toUpperCase();
    } else if (user.email?.isNotEmpty ?? false) {
      return user.email![0].toUpperCase();
    }
    return 'U';
  }
}
