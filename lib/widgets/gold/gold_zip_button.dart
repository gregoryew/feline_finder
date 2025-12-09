import 'package:flutter/material.dart';
import '../../theme.dart';

class GoldZipButton extends StatelessWidget {
  final String zip;
  final VoidCallback onTap;

  const GoldZipButton({
    Key? key,
    required this.zip,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 140,
        minHeight: 55,
      ),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Stack(
                  children: [
                    // Outer beveled face
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFBE7A1), // Highlight top-left
                            Color(0xFFE0A93C), // Body gold bottom-right
                          ],
                        ),
                        border: Border.all(
                          color: Color(0xFFC3922E), // Raised edge
                          width: 2.0,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(2, 3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    // Inner recessed rim
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
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
                              width: 1.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                spreadRadius: -4,
                                offset: Offset(1.5, 1.5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "Zip: $zip",
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
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
        ),
      ),
    );
  }
}
