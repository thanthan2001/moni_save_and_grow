import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppIconResolver {
  AppIconResolver._();

  static IconData resolve({
    required int codePoint,
    String? fontFamily,
    String? fontPackage,
  }) {
    final normalizedFamily = (fontFamily ?? '').toLowerCase();
    final normalizedPackage = (fontPackage ?? '').toLowerCase();
    final isFontAwesome = normalizedFamily.contains('fontawesome') ||
        normalizedPackage.contains('font_awesome');

    if (isFontAwesome) {
      return _fontAwesomeIcons[codePoint] ??
          _materialIcons[codePoint] ??
          Icons.category;
    }

    return _materialIcons[codePoint] ??
        _fontAwesomeIcons[codePoint] ??
        Icons.category;
  }

  static final Map<int, IconData> _materialIcons = {
    Icons.category.codePoint: Icons.category,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.shopping_bag.codePoint: Icons.shopping_bag,
    Icons.school.codePoint: Icons.school,
    Icons.favorite.codePoint: Icons.favorite,
    Icons.movie.codePoint: Icons.movie,
    Icons.home.codePoint: Icons.home,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.savings.codePoint: Icons.savings,
    Icons.trending_up.codePoint: Icons.trending_up,
    Icons.more_horiz.codePoint: Icons.more_horiz,
  };

  static final Map<int, IconData> _fontAwesomeIcons = {
    FontAwesomeIcons.utensils.codePoint: FontAwesomeIcons.utensils,
    FontAwesomeIcons.car.codePoint: FontAwesomeIcons.car,
    FontAwesomeIcons.shoppingBag.codePoint: FontAwesomeIcons.shoppingBag,
    FontAwesomeIcons.gamepad.codePoint: FontAwesomeIcons.gamepad,
    FontAwesomeIcons.heartPulse.codePoint: FontAwesomeIcons.heartPulse,
    FontAwesomeIcons.graduationCap.codePoint: FontAwesomeIcons.graduationCap,
    FontAwesomeIcons.moneyBill.codePoint: FontAwesomeIcons.moneyBill,
    FontAwesomeIcons.gift.codePoint: FontAwesomeIcons.gift,
    FontAwesomeIcons.chartLine.codePoint: FontAwesomeIcons.chartLine,
    FontAwesomeIcons.ellipsis.codePoint: FontAwesomeIcons.ellipsis,
    FontAwesomeIcons.home.codePoint: FontAwesomeIcons.home,
    FontAwesomeIcons.shirt.codePoint: FontAwesomeIcons.shirt,
    FontAwesomeIcons.plane.codePoint: FontAwesomeIcons.plane,
    FontAwesomeIcons.dumbbell.codePoint: FontAwesomeIcons.dumbbell,
    FontAwesomeIcons.mobile.codePoint: FontAwesomeIcons.mobile,
    FontAwesomeIcons.wifi.codePoint: FontAwesomeIcons.wifi,
    FontAwesomeIcons.bolt.codePoint: FontAwesomeIcons.bolt,
    FontAwesomeIcons.paw.codePoint: FontAwesomeIcons.paw,
    FontAwesomeIcons.book.codePoint: FontAwesomeIcons.book,
    FontAwesomeIcons.film.codePoint: FontAwesomeIcons.film,
    FontAwesomeIcons.music.codePoint: FontAwesomeIcons.music,
    FontAwesomeIcons.piggyBank.codePoint: FontAwesomeIcons.piggyBank,
    FontAwesomeIcons.handHoldingDollar.codePoint:
        FontAwesomeIcons.handHoldingDollar,
    FontAwesomeIcons.calculator.codePoint: FontAwesomeIcons.calculator,
    FontAwesomeIcons.creditCard.codePoint: FontAwesomeIcons.creditCard,
    FontAwesomeIcons.hospital.codePoint: FontAwesomeIcons.hospital,
    FontAwesomeIcons.pills.codePoint: FontAwesomeIcons.pills,
    FontAwesomeIcons.suitcase.codePoint: FontAwesomeIcons.suitcase,
    FontAwesomeIcons.briefcase.codePoint: FontAwesomeIcons.briefcase,
    FontAwesomeIcons.baby.codePoint: FontAwesomeIcons.baby,
    FontAwesomeIcons.users.codePoint: FontAwesomeIcons.users,
    FontAwesomeIcons.heart.codePoint: FontAwesomeIcons.heart,
    FontAwesomeIcons.star.codePoint: FontAwesomeIcons.star,
    FontAwesomeIcons.fire.codePoint: FontAwesomeIcons.fire,
    FontAwesomeIcons.leaf.codePoint: FontAwesomeIcons.leaf,
    FontAwesomeIcons.tools.codePoint: FontAwesomeIcons.tools,
    FontAwesomeIcons.wrench.codePoint: FontAwesomeIcons.wrench,
  };
}
