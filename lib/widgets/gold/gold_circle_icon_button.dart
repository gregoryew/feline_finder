import 'package:flutter/material.dart';

class GoldCircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected; // for favorites toggle

  const GoldCircleIconButton({
    Key? key,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFBE7A1), // highlight
              Color(0xFFE0A93C), // body gold
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Color(0xFFC3922E),
            width: 2.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              offset: Offset(1, 2),
              blurRadius: 5,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.bottomRight,
              end: Alignment.topLeft,
              colors: [
                Color(0xFFEAC46E),
                Color(0xFFC58F2B),
              ],
            ),
            border: Border.all(
              color: Color(0xFFB07A26),
              width: 1.3,
            ),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected ? Colors.pinkAccent : Colors.white,
              size: 26,
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black45,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
