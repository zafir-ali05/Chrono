import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:persistent_bottom_nav_bar/persistent_bottom_nav_bar.dart';
import 'home_screen.dart';
import 'classrooms_screen.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final bool? isSignUp;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.isSignUp,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late PersistentTabController _controller;
  late bool _hideNavBar;

  @override
  void initState() {
    super.initState();
    _controller = PersistentTabController(initialIndex: widget.initialIndex);
    _hideNavBar = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildScreens() {
    return [
      const HomeScreen(),
      const CalendarScreen(),
      const ClassroomsScreen(),
      ProfileScreen(initialIsSignUp: widget.isSignUp),
    ];
  }

  Color _getActiveColorPrimary(int index) {
    // Return different colors for each tab
    switch (index) {
      case 0:
        return Theme.of(context).colorScheme.primary;
      case 1:
        return Theme.of(context).colorScheme.tertiary;
      case 2:
        return Theme.of(context).colorScheme.secondary;
      case 3:
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  List<PersistentBottomNavBarItem> _navBarsItems() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return [
      // Home
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.home),
        title: "Home",
        opacity: 0.9,
        activeColorPrimary: _getActiveColorPrimary(0),
        activeColorSecondary: Colors.white, // For style10, this is the color of icon/text when active
        inactiveColorPrimary: isDarkMode ? Colors.grey : Colors.black54,
      ),
      
      // Calendar
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.calendar),
        title: "Calendar",
        opacity: 0.9,
        activeColorPrimary: _getActiveColorPrimary(1),
        activeColorSecondary: Colors.white, // For style10
        inactiveColorPrimary: isDarkMode ? Colors.grey : Colors.black54,
      ),
      
      // Classrooms
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.group),
        title: "Classrooms",
        opacity: 0.9,
        activeColorPrimary: _getActiveColorPrimary(2),
        activeColorSecondary: Colors.white, // For style10
        inactiveColorPrimary: isDarkMode ? Colors.grey : Colors.black54,
      ),
      
      // Profile
      PersistentBottomNavBarItem(
        icon: const Icon(CupertinoIcons.person),
        title: "Profile",
        opacity: 0.9,
        activeColorPrimary: _getActiveColorPrimary(3),
        activeColorSecondary: Colors.white, // For style10
        inactiveColorPrimary: isDarkMode ? Colors.grey : Colors.black54,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: PersistentTabView(
        context,
        controller: _controller,
        screens: _buildScreens(),
        items: _navBarsItems(),
        confineToSafeArea: true,
        backgroundColor: isDarkMode 
            ? Colors.black.withOpacity(0.9) 
            : Colors.white, // Background color of bottom nav bar
        handleAndroidBackButtonPress: true,
        resizeToAvoidBottomInset: true, // Resize when keyboard appears
        stateManagement: true, // Preserve state when switching tabs
        hideNavigationBarWhenKeyboardAppears: true, // Hide nav bar when keyboard appears
        decoration: NavBarDecoration(
          borderRadius: BorderRadius.circular(20.0), // Rounded corners
          colorBehindNavBar: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, -2),
            )
          ],
        ),
        //popAllScreensOnTapOfSelectedTab: true,
        //popActionScreens: PopActionScreensType.all,
        animationSettings: const NavBarAnimationSettings(
          navBarItemAnimation: ItemAnimationSettings(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          ),
        
        screenTransitionAnimation: ScreenTransitionAnimationSettings(
          animateTabTransition: true,
          curve: Curves.easeInOut,
          duration: Duration(milliseconds: 200),
        ),
        
      ),

      // On item tap, change the indexnavBarStyle: NavBarStyle.style10, // The specific style you requested
        isVisible: !_hideNavBar, // Control visibility dynamically if needed
        // Hide nav bar on scroll (optional, can be removed if not needed)
        //hideStatus: _hideNavBar,
        navBarHeight: 65, // Standard height
        navBarStyle: NavBarStyle.style7,
      ),
    );
  }
}


