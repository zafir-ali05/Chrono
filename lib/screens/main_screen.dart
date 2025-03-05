import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'home_screen.dart';
import 'groups_screen.dart';
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
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0
              ? 'Upcoming Assignments'
              : _currentIndex == 1
                  ? 'Calendar'
                  : _currentIndex == 2
                      ? 'Groups'
                      : 'Profile',
        ),
        elevation: 0,
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const HomeScreen(),        // Index 0
          const CalendarScreen(),    // Index 1 (moved up)
          const GroupsScreen(),      // Index 2 (moved down) 
          ProfileScreen(initialIsSignUp: widget.isSignUp), // Index 3
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 50),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SalomonBottomBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            margin: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            itemPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            items: [
              // Home (Index 0)
              SalomonBottomBarItem(
                icon: const Icon(Icons.assignment_outlined, size: 24),
                activeIcon: const Icon(Icons.assignment, size: 24),
                title: const Text("Home"),
                selectedColor: Theme.of(context).colorScheme.primary,
                unselectedColor: Colors.grey,
              ),
              // Calendar (Index 1)
              SalomonBottomBarItem(
                icon: const Icon(Icons.calendar_month_outlined, size: 24),
                activeIcon: const Icon(Icons.calendar_month, size: 24),
                title: const Text("Calendar"),
                selectedColor: Theme.of(context).colorScheme.tertiary,
                unselectedColor: Colors.grey,
              ),
              // Groups (Index 2)
              SalomonBottomBarItem(
                icon: const Icon(Icons.group_outlined, size: 24),
                activeIcon: const Icon(Icons.group, size: 24),
                title: const Text("Groups"),
                selectedColor: Theme.of(context).colorScheme.secondary,
                unselectedColor: Colors.grey,
              ),
              // Profile (Index 3)
              SalomonBottomBarItem(
                icon: const Icon(Icons.person_outline, size: 24),
                activeIcon: const Icon(Icons.person, size: 24),
                title: const Text("Profile"),
                selectedColor: Theme.of(context).colorScheme.tertiary,
                unselectedColor: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


