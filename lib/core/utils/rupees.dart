import 'package:intl/intl.dart';

final _grouped = NumberFormat('#,##,##0', 'en_IN');

/// `₹9,140`. Indian grouping, no paise: a partner's earnings are always whole
/// rupees, and an ungrouped ₹19380 has to be counted digit by digit.
String rupees(num amount) => '₹${_grouped.format(amount.round())}';
