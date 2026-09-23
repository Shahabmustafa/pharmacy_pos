import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Names in the custom SVG icon set (assets/icons/*.svg).
class AppIcons {
  AppIcons._();

  static const String accountBalanceWallet = 'account_balance_wallet';
  static const String add = 'add';
  static const String addCircle = 'add_circle';
  static const String analytics = 'analytics';
  static const String arrowBack = 'arrow_back';
  static const String barChart = 'bar_chart';
  static const String calendarToday = 'calendar_today';
  static const String checkCircle = 'check_circle';
  static const String checkCircleOutline = 'check_circle';
  static const String clear = 'clear';
  static const String close = 'close';
  static const String cloudSync = 'cloud_sync';
  static const String dashboard = 'dashboard';
  static const String deleteOutline = 'delete_outline';
  static const String discount = 'discount';
  static const String editOutlined = 'edit_outlined';
  static const String eventBusy = 'event_busy';
  static const String fileDownload = 'file_download';
  static const String inventory = 'inventory';
  static const String inventory2 = 'inventory_2';
  static const String inventory2Outlined = 'inventory_2';
  static const String localPharmacy = 'local_pharmacy';
  static const String localShipping = 'local_shipping';
  static const String lockOutline = 'lock_outline';
  static const String logout = 'logout';
  static const String medication = 'medication';
  static const String menu = 'menu';
  static const String menuOpen = 'menu_open';
  static const String pauseCircleOutline = 'pause_circle_outline';
  static const String payment = 'payment';
  static const String payments = 'payments';
  static const String people = 'people';
  static const String person = 'person';
  static const String personAdd = 'person_add';
  static const String personOutline = 'person';
  static const String pointOfSale = 'point_of_sale';
  static const String priceCheck = 'price_check';
  static const String print = 'print';
  static const String qrCodeScanner = 'qr_code_scanner';
  static const String receipt = 'receipt';
  static const String receiptLong = 'receipt_long';
  static const String remove = 'remove';
  static const String restore = 'restore';
  static const String save = 'save';
  static const String search = 'search';
  static const String settings = 'settings';
  static const String shoppingCart = 'shopping_cart';
  static const String shoppingCartOutlined = 'shopping_cart';
  static const String store = 'store';
  static const String sync = 'sync';
  static const String syncProblem = 'sync_problem';
  static const String today = 'today';
  static const String trendingUp = 'trending_up';
  static const String visibility = 'visibility';
  static const String visibilityOff = 'visibility_off';
  static const String warning = 'warning';
  static const String warningAmber = 'warning_amber';
  static const String wifiOff = 'wifi_off';
  static const String straighten = 'straighten';
  static const String chevronRight = 'chevron_right';
  static const String acUnit = 'ac_unit';
  static const String science = 'science';
}

/// Drop-in replacement for [Icon] that renders from the custom SVG icon set,
/// inheriting size/color from the ambient [IconTheme] the same way [Icon] does.
class AppIcon extends StatelessWidget {
  final String name;
  final double? size;
  final Color? color;

  const AppIcon(this.name, {super.key, this.size, this.color});

  // Our SVGs draw edge-to-edge in their 24x24 viewBox, while Material's Icons
  // font glyphs sit inside a built-in visual margin. Scaling the rendered
  // glyph down (while keeping the outer box at resolvedSize) matches that
  // same visual weight instead of looking oversized next to text/buttons.
  static const double _visualScale = 0.78;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedColor = color ?? iconTheme.color ?? Colors.black;
    final resolvedSize = size ?? iconTheme.size ?? 24;
    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/$name.svg',
          width: resolvedSize * _visualScale,
          height: resolvedSize * _visualScale,
          colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        ),
      ),
    );
  }
}
