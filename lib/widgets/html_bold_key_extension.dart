import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

/// Wraps the first <b> or <strong> in the HTML with a keyed widget so we can
/// scroll to it (e.g. Scrollable.ensureVisible(key.currentContext!)).
class BoldKeyExtension extends HtmlExtension {
  BoldKeyExtension(this.scrollTargetKey)
      : _firstDone = [false];

  final GlobalKey scrollTargetKey;
  final List<bool> _firstDone;

  @override
  Set<String> get supportedTags => {'b', 'strong'};

  @override
  StyledElement prepare(
      ExtensionContext context, List<StyledElement> children) {
    return context.parser.prepareFromExtension(
      context,
      children,
      extensionsToIgnore: {this},
    );
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final defaultSpan = context.parser.buildFromExtension(
      context,
      extensionsToIgnore: {this},
    );
    if (!_firstDone[0] && context.style != null) {
      _firstDone[0] = true;
      return WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: KeyedSubtree(
          key: scrollTargetKey,
          child: CssBoxWidget.withInlineSpanChildren(
            children: [defaultSpan],
            style: context.style!,
          ),
        ),
      );
    }
    return defaultSpan;
  }
}
