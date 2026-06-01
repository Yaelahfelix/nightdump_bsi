import 'package:flutter/material.dart';

/// Nav bar bersama — semua navigasi via named routes, tidak ada import halaman.
/// currentIndex: 0=Home, 1=Insight, 2=Catat(+), 3=Histori, 4=Tugas
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  const AppNavBar({super.key, required this.currentIndex});

  static const _routes = ['/home', '/insights', '/notes', '/history', '/tasks'];

  void _go(BuildContext context, int index) {
    if (index == currentIndex) return;
    if (index == 2) {
      Navigator.pushNamed(context, '/notes');
    } else {
      Navigator.pushReplacementNamed(context, _routes[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF161632).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _icon(context, 0, Icons.nights_stay_outlined, Icons.nights_stay),
          _icon(context, 1, Icons.bar_chart_rounded, Icons.bar_chart_rounded),
          _centerBtn(context),
          _icon(context, 3, Icons.history, Icons.history),
          _icon(context, 4, Icons.checklist_outlined, Icons.checklist),
        ],
      ),
    );
  }

  Widget _icon(BuildContext ctx, int idx, IconData off, IconData on) {
    final active = currentIndex == idx;
    return IconButton(
      icon: Icon(
        active ? on : off,
        color: active ? const Color(0xFFD1B3FF) : Colors.white38,
      ),
      onPressed: () => _go(ctx, idx),
    );
  }

  Widget _centerBtn(BuildContext ctx) {
    final active = currentIndex == 2;
    return GestureDetector(
      onTap: () => _go(ctx, 2),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0xFFD1B3FF)
              : const Color(0xFFD1B3FF).withValues(alpha: 0.25),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFD1B3FF).withValues(alpha: 0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Icon(
          Icons.add,
          color: active ? const Color(0xFF13132B) : Colors.white54,
          size: 28,
        ),
      ),
    );
  }
}
