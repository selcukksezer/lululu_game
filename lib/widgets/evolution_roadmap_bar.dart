import 'package:flutter/material.dart';
import '../theme/lululu_theme.dart';
import '../models/insect_tier.dart';
import 'sticker_image.dart';

class EvolutionRoadmapBar extends StatelessWidget {
  final InsectTier currentHighest;

  const EvolutionRoadmapBar({
    super.key,
    required this.currentHighest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LululuColors.darkObsidian),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: InsectTier.values.map((tier) {
            final isUnlocked = tier.index <= currentHighest.index;
            final isNext = tier.index == currentHighest.index + 1;
            final isLast = tier == InsectTier.values.last;

            return Row(
              children: [
                Tooltip(
                  message: '${tier.name} (${tier.title})',
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isUnlocked
                            ? tier.color
                            : (isNext ? LululuColors.darkObsidian : LululuColors.darkObsidian),
                        width: isUnlocked ? 2.0 : 1.0,
                      ),
                      color: isUnlocked
                          ? tier.color.withValues(alpha: 0.2)
                          : Colors.black45,
                    ),
                    child: isUnlocked
                        ? StickerImage(
                            assetPath: tier.assetPath,
                            width: 28,
                            height: 28,
                          )
                        : Icon(
                            Icons.question_mark,
                            size: 14,
                            color: isNext ? LululuColors.mutedTitanium : LululuColors.darkObsidian,
                          ),
                  ),
                ),
                if (!isLast)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: LululuColors.darkObsidian,
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
