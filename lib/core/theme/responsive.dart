import 'package:flutter/widgets.dart';

/// Form factors the app lays out for.
///
/// The breakpoints match the widths the website was audited at (320–1440), so a
/// screen that reads well in one place reads well in the other.
enum FormFactor {
  /// Small and standard phones in portrait — 320–599.
  compact,

  /// Large phones in landscape and small tablets — 600–904.
  medium,

  /// Tablets and iPads — 905 and up.
  expanded,
}

extension FormFactorX on FormFactor {
  bool get isCompact => this == FormFactor.compact;
  bool get isTablet => this != FormFactor.compact;
  bool get isExpanded => this == FormFactor.expanded;
}

class Responsive {
  const Responsive._();

  static const double compactMax = 600;
  static const double mediumMax = 905;

  /// Anything wider than this is padded rather than stretched, so a 12-inch iPad
  /// does not render a single column of text a metre wide.
  static const double maxContentWidth = 720;

  static FormFactor of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static FormFactor fromWidth(double width) {
    if (width < compactMax) return FormFactor.compact;
    if (width < mediumMax) return FormFactor.medium;
    return FormFactor.expanded;
  }

  /// Column count for a profile grid at the given width.
  static int gridColumns(double width) {
    if (width < 380) return 2;
    if (width < compactMax) return 2;
    if (width < mediumMax) return 3;
    if (width < 1200) return 4;
    return 5;
  }

  /// True when the on-screen keyboard is covering part of the layout. Screens
  /// use it to collapse decorative headers rather than letting a form scroll
  /// out of reach.
  static bool keyboardVisible(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom > 80;
}

/// Centres and width-caps its child on tablets while leaving phones alone.
///
/// Used at the top of every scrollable screen: it is the single reason the app
/// does not simply stretch the phone UI across an iPad.
class ContentContainer extends StatelessWidget {
  const ContentContainer({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
