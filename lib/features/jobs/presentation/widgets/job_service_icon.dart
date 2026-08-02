import 'package:flutter/material.dart';

import '../../../../core/theme/xpert_tokens.dart';
import '../../data/jobs_api.dart';

/// The square that leads a job card.
///
/// It used to be a hardcoded broom on every job, including the laundry ones.
/// The real service image is used when the catalogue has one; otherwise the
/// category picks the icon. A wrong-ish icon is a small cost — unlike, say, a
/// mismatched legal document — and it beats one icon for everything.
class JobServiceIcon extends StatelessWidget {
  const JobServiceIcon({super.key, required this.job, this.size = 48});

  final PartnerJob job;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = job.serviceImageUrl;
    final radius = BorderRadius.circular(size * 0.28);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: XpertColors.secondary,
        borderRadius: radius,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: url == null || url.isEmpty
          ? Icon(
              _iconFor(job.serviceCategoryName ?? job.serviceName),
              size: size * 0.44,
              color: XpertColors.onSurface,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => Icon(
                _iconFor(job.serviceCategoryName ?? job.serviceName),
                size: size * 0.44,
                color: XpertColors.onSurface,
              ),
            ),
    );
  }
}

IconData _iconFor(String? category) {
  final name = (category ?? '').toLowerCase();
  if (name.contains('laundry') || name.contains('iron')) {
    return Icons.local_laundry_service_rounded;
  }
  if (name.contains('cook') || name.contains('kitchen') || name.contains('chef')) {
    return Icons.restaurant_rounded;
  }
  if (name.contains('dish') || name.contains('utensil')) {
    return Icons.countertops_rounded;
  }
  if (name.contains('clean') || name.contains('sweep') || name.contains('mop')) {
    return Icons.cleaning_services_rounded;
  }
  return Icons.home_repair_service_rounded;
}
