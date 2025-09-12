import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentTime = "";

  @override
  void initState() {
    super.initState();
    _updateTime();
    Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = DateFormat('HH:mm').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final buttonWidth = screenSize.width * 0.18;
    final buttonHeight = buttonWidth * 0.75;
    final bigButtonWidth = (buttonWidth * 2) + (screenSize.width * 0.02);
    final bigButtonHeight = (buttonHeight * 2) + (screenSize.height * 0.02);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // CLOCK TOP RIGHT
            Positioned(
              top: 16,
              right: 16,
              child: Text(
                _currentTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // MAIN CONTENT
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LEFT GRID
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BIG "EN DIRECT" BUTTON
                          _buildMainButton(
                            label: "EN DIRECT",
                            icon: Icons.tv,
                            width: bigButtonWidth,
                            height: bigButtonHeight,
                            onTap: () {
                              Navigator.pushNamed(context, '/channels');
                            },
                          ),
                          SizedBox(width: screenSize.width * 0.02),
                          // RIGHT COLUMN SMALL BUTTONS
                          Column(
                            children: [
                              _buildMainButton(
                                label: "FILMS",
                                icon: Icons.movie,
                                width: buttonWidth,
                                height: buttonHeight,
                                onTap: () {
                                  Navigator.pushNamed(context, '/movies');
                                },
                              ),
                              SizedBox(height: screenSize.height * 0.02),
                              _buildMainButton(
                                label: "SÉRIES",
                                icon: Icons.video_library,
                                width: buttonWidth,
                                height: buttonHeight,
                                onTap: () {
                                  Navigator.pushNamed(context, '/series');
                                },
                              ),
                              SizedBox(height: screenSize.height * 0.02),
                              _buildMainButton(
                                label: "COMPTE",
                                icon: Icons.person,
                                width: buttonWidth,
                                height: buttonHeight,
                                onTap: () {
                                  Navigator.pushNamed(context, '/account');
                                },
                              ),
                              SizedBox(height: screenSize.height * 0.02),
                              _buildMainButton(
                                label: "LISTE",
                                icon: Icons.playlist_play,
                                width: buttonWidth,
                                height: buttonHeight,
                                onTap: () {
                                  Navigator.pushNamed(context, '/playlist');
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(width: screenSize.width * 0.05),

                  // RIGHT PANEL BUTTONS
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildRightButton(
                        label: "PARAMÈTRES",
                        icon: Icons.settings,
                        width: buttonWidth,
                        height: buttonHeight * 0.7,
                        onTap: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                      ),
                      SizedBox(height: screenSize.height * 0.02),
                      _buildRightButton(
                        label: "RECHARGER",
                        icon: Icons.refresh,
                        width: buttonWidth,
                        height: buttonHeight * 0.7,
                        onTap: () {
                          setState(() {});
                        },
                      ),
                      SizedBox(height: screenSize.height * 0.02),
                      _buildRightButton(
                        label: "QUITTER",
                        icon: Icons.exit_to_app,
                        width: buttonWidth,
                        height: buttonHeight * 0.7,
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required String label,
    required IconData icon,
    required double width,
    required double height,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF5D2C2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: height * 0.35),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightButton({
    required String label,
    required IconData icon,
    required double width,
    required double height,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
