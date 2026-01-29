import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:value_layout_builder/value_layout_builder.dart';

import '../../flutter_sticky_header.dart';

/// Signature used by [SliverStickyHeader.builder] to build the header
/// when the sticky header state has changed.
typedef Widget SliverStickyHeaderWidgetBuilder(
    BuildContext context,
    SliverStickyHeaderState state,
    );

class StickyHeaderController with ChangeNotifier {
  double get stickyHeaderScrollOffset => _stickyHeaderScrollOffset;
  double _stickyHeaderScrollOffset = 0;

  set stickyHeaderScrollOffset(double value) {
    if (_stickyHeaderScrollOffset != value) {
      _stickyHeaderScrollOffset = value;
      notifyListeners();
    }
  }
}

class DefaultStickyHeaderController extends StatefulWidget {
  const DefaultStickyHeaderController({
    Key? key,
    required this.child,
  }) : super(key: key);

  final Widget child;

  static StickyHeaderController? of(BuildContext context) {
    final _StickyHeaderControllerScope? scope = context
        .dependOnInheritedWidgetOfExactType<_StickyHeaderControllerScope>();
    return scope?.controller;
  }

  @override
  _DefaultStickyHeaderControllerState createState() =>
      _DefaultStickyHeaderControllerState();
}

class _DefaultStickyHeaderControllerState
    extends State<DefaultStickyHeaderController> {
  StickyHeaderController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = StickyHeaderController();
  }

  @override
  void dispose() {
    _controller!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _StickyHeaderControllerScope(
      controller: _controller,
      child: widget.child,
    );
  }
}

class _StickyHeaderControllerScope extends InheritedWidget {
  const _StickyHeaderControllerScope({
    Key? key,
    this.controller,
    required Widget child,
  }) : super(key: key, child: child);

  final StickyHeaderController? controller;

  @override
  bool updateShouldNotify(_StickyHeaderControllerScope old) {
    return controller != old.controller;
  }
}

@immutable
class SliverStickyHeaderState {
  const SliverStickyHeaderState(
      this.scrollPercentage,
      this.isPinned,
      );

  final double scrollPercentage;
  final bool isPinned;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SliverStickyHeaderState) return false;
    final SliverStickyHeaderState typedOther = other;
    return scrollPercentage == typedOther.scrollPercentage &&
        isPinned == typedOther.isPinned;
  }

  @override
  int get hashCode {
    return Object.hash(scrollPercentage, isPinned);
  }
}

class SliverStickyHeader extends RenderObjectWidget {
  /// Creates a sliver that displays the [header] before its [sliver].
  /// [footer] is displayed after.
  SliverStickyHeader({
    Key? key,
    this.header,
    this.sliver,
    this.footer,
    this.overlapsContent = false,
    this.sticky = true,
    this.stickyFooter = true,
    this.controller,
  }) : super(key: key);

  SliverStickyHeader.builder({
    Key? key,
    required SliverStickyHeaderWidgetBuilder builder,
    Widget? sliver,
    Widget? footer,
    bool overlapsContent = false,
    bool sticky = true,
    bool stickyFooter = true,
    StickyHeaderController? controller,
  }) : this(
    key: key,
    header: ValueLayoutBuilder<SliverStickyHeaderState>(
      builder: (context, constraints) =>
          builder(context, constraints.value),
    ),
    sliver: sliver,
    footer: footer,
    overlapsContent: overlapsContent,
    sticky: sticky,
    stickyFooter: stickyFooter,
    controller: controller,
  );

  final Widget? header;
  final Widget? sliver;
  final Widget? footer;
  final bool overlapsContent;
  final bool sticky;
  final bool stickyFooter;
  final StickyHeaderController? controller;

  @override
  RenderSliverStickyHeader createRenderObject(BuildContext context) {
    return RenderSliverStickyHeader(
      overlapsContent: overlapsContent,
      sticky: sticky,
      stickyFooter: stickyFooter,
      controller: controller ?? DefaultStickyHeaderController.of(context),
    );
  }

  @override
  SliverStickyHeaderRenderObjectElement createElement() =>
      SliverStickyHeaderRenderObjectElement(this);

  @override
  void updateRenderObject(
      BuildContext context,
      RenderSliverStickyHeader renderObject,
      ) {
    renderObject
      ..overlapsContent = overlapsContent
      ..sticky = sticky
      ..stickyFooter = stickyFooter
      ..controller = controller ?? DefaultStickyHeaderController.of(context);
  }
}

class SliverStickyHeaderRenderObjectElement extends RenderObjectElement {
  SliverStickyHeaderRenderObjectElement(SliverStickyHeader widget)
      : super(widget);

  @override
  SliverStickyHeader get widget => super.widget as SliverStickyHeader;

  Element? _header;
  Element? _sliver;
  Element? _footer;

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_header != null) visitor(_header!);
    if (_sliver != null) visitor(_sliver!);
    if (_footer != null) visitor(_footer!);
  }

  @override
  void forgetChild(Element child) {
    super.forgetChild(child);
    if (child == _header) _header = null;
    if (child == _sliver) _sliver = null;
    if (child == _footer) _footer = null;
  }

  @override
  void mount(Element? parent, dynamic newSlot) {
    super.mount(parent, newSlot);
    _header = updateChild(_header, widget.header, 0);
    _sliver = updateChild(_sliver, widget.sliver, 1);
    _footer = updateChild(_footer, widget.footer, 2);
  }

  @override
  void update(SliverStickyHeader newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _header = updateChild(_header, widget.header, 0);
    _sliver = updateChild(_sliver, widget.sliver, 1);
    _footer = updateChild(_footer, widget.footer, 2);
  }

  @override
  void insertRenderObjectChild(RenderObject child, int? slot) {
    final RenderSliverStickyHeader renderObject =
    this.renderObject as RenderSliverStickyHeader;
    if (slot == 0) renderObject.header = child as RenderBox?;
    if (slot == 1) renderObject.child = child as RenderSliver?;
    if (slot == 2) renderObject.footer = child as RenderBox?;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(RenderObject child, slot, newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, slot) {
    final RenderSliverStickyHeader renderObject =
    this.renderObject as RenderSliverStickyHeader;
    if (renderObject.header == child) renderObject.header = null;
    if (renderObject.child == child) renderObject.child = null;
    if (renderObject.footer == child) renderObject.footer = null;
    assert(renderObject == this.renderObject);
  }
}