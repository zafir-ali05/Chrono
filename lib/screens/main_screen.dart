import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'home_screen.dart';
import 'classrooms_screen.dart';
import 'profile_screen.dart';
import 'calendar_screen.dart';
import 'package:animations/animations.dart';

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
                      ? 'Classrooms' 
                      : 'Profile',
        ),
        elevation: 0,
      ),
      body: PageTransitionSwitcher(
        transitionBuilder: (
          Widget child,
          Animation<double> primaryAnimation,
          Animation<double> secondaryAnimation,
        ) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: IndexedStack(
          index: _currentIndex,
          children: [
            const HomeScreen(),
            const CalendarScreen(),
            const ClassroomsScreen(),
            ProfileScreen(initialIsSignUp: widget.isSignUp),
          ],
        ),
      ),
      bottomNavigationBar: SalomonBottomBar(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          SalomonBottomBarItem(
            icon: const Icon(Icons.assignment_outlined, size: 24),
            activeIcon: const Icon(Icons.assignment, size: 24),
            title: const Text("Home"),
            selectedColor: Theme.of(context).colorScheme.primary,
            unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.calendar_month_outlined, size: 24),
            activeIcon: const Icon(Icons.calendar_month, size: 24),
            title: const Text("Calendar"),
            selectedColor: Theme.of(context).colorScheme.tertiary,
            unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.group_outlined, size: 24),
            activeIcon: const Icon(Icons.group, size: 24),
            title: const Text("Classrooms"),
            selectedColor: Theme.of(context).colorScheme.secondary,
            unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: const Icon(Icons.person_outline, size: 24),
            activeIcon: const Icon(Icons.person, size: 24),
            title: const Text("Profile"),
            selectedColor: Theme.of(context).colorScheme.tertiary,
            unselectedColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}


