import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) => width(context) < 600;
  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 900;
  static bool isDesktop(BuildContext context) => width(context) >= 900;

  // Responsive font sizes
  static double sp(BuildContext context, double size) {
    double screenWidth = width(context);
    if (screenWidth < 360) return size * 0.85;
    if (screenWidth < 400) return size * 0.9;
    if (screenWidth > 600) return size * 1.1;
    return size;
  }

  // Responsive spacing
  static double wp(BuildContext context, double percentage) {
    return width(context) * percentage / 100;
  }

  static double hp(BuildContext context, double percentage) {
    return height(context) * percentage / 100;
  }

  // Responsive padding
  static EdgeInsets pagePadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(16);
    if (isTablet(context)) return const EdgeInsets.all(24);
    return const EdgeInsets.all(32);
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(12);
    if (isTablet(context)) return const EdgeInsets.all(16);
    return const EdgeInsets.all(20);
  }

  // Responsive icon sizes
  static double iconSize(BuildContext context, {double base = 24}) {
    if (isMobile(context)) return base;
    if (isTablet(context)) return base * 1.2;
    return base * 1.5;
  }
}
