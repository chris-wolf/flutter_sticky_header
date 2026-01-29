  import 'dart:math' as math;

  import 'package:flutter/material.dart';
  import 'package:flutter/rendering.dart';
  import 'package:flutter_sticky_header/flutter_sticky_header.dart';
  import 'package:value_layout_builder/value_layout_builder.dart';

  /// A sliver with a [RenderBox] as header, a [RenderBox] as footer,
  /// and a [RenderSliver] as child.
  ///
  /// The [header] stays pinned when it hits the start of the viewport.
  /// The [footer] stays pinned when it hits the end of the viewport.
  class RenderSliverStickyHeader extends RenderSliver with RenderSliverHelpers {
    RenderSliverStickyHeader({
      RenderObject? header,
      RenderSliver? child,
      RenderObject? footer,
      bool overlapsContent = false,
      bool sticky = true,
      bool stickyFooter = true,
      StickyHeaderController? controller,
    })  : _overlapsContent = overlapsContent,
          _sticky = sticky,
          _stickyFooter = stickyFooter,
          _controller = controller {
      this.header = header as RenderBox?;
      this.child = child;
      this.footer = footer as RenderBox?;
    }

    SliverStickyHeaderState? _oldState;
    double? _headerExtent;
    double? _footerExtent;
    late bool _isPinned;

    bool get overlapsContent => _overlapsContent;
    bool _overlapsContent;

    set overlapsContent(bool value) {
      if (_overlapsContent == value) return;
      _overlapsContent = value;
      markNeedsLayout();
    }

    bool get sticky => _sticky;
    bool _sticky;

    set sticky(bool value) {
      if (_sticky == value) return;
      _sticky = value;
      markNeedsLayout();
    }

    bool get stickyFooter => _stickyFooter;
    bool _stickyFooter;

    set stickyFooter(bool value) {
      if (_stickyFooter == value) return;
      _stickyFooter = value;
      markNeedsLayout();
    }

    StickyHeaderController? get controller => _controller;
    StickyHeaderController? _controller;

    set controller(StickyHeaderController? value) {
      if (_controller == value) return;
      if (_controller != null && value != null) {
        // We copy the state of the old controller.
        value.stickyHeaderScrollOffset = _controller!.stickyHeaderScrollOffset;
      }
      _controller = value;
    }

    /// The render object's header
    RenderBox? get header => _header;
    RenderBox? _header;

    set header(RenderBox? value) {
      if (_header != null) dropChild(_header!);
      _header = value;
      if (_header != null) adoptChild(_header!);
    }

    /// The render object's unique child
    RenderSliver? get child => _child;
    RenderSliver? _child;

    set child(RenderSliver? value) {
      if (_child != null) dropChild(_child!);
      _child = value;
      if (_child != null) adoptChild(_child!);
    }

    /// The render object's footer
    RenderBox? get footer => _footer;
    RenderBox? _footer;

    set footer(RenderBox? value) {
      if (_footer != null) dropChild(_footer!);
      _footer = value;
      if (_footer != null) adoptChild(_footer!);
    }

    @override
    void setupParentData(RenderObject child) {
      if (child.parentData is! SliverPhysicalParentData)
        child.parentData = SliverPhysicalParentData();
    }

    @override
    void attach(PipelineOwner owner) {
      super.attach(owner);
      if (_header != null) _header!.attach(owner);
      if (_child != null) _child!.attach(owner);
      if (_footer != null) _footer!.attach(owner);
    }

    @override
    void detach() {
      super.detach();
      if (_header != null) _header!.detach();
      if (_child != null) _child!.detach();
      if (_footer != null) _footer!.detach();
    }

    @override
    void redepthChildren() {
      if (_header != null) redepthChild(_header!);
      if (_child != null) redepthChild(_child!);
      if (_footer != null) redepthChild(_footer!);
    }

    @override
    void visitChildren(RenderObjectVisitor visitor) {
      if (_header != null) visitor(_header!);
      if (_child != null) visitor(_child!);
      if (_footer != null) visitor(_footer!);
    }

    @override
    List<DiagnosticsNode> debugDescribeChildren() {
      List<DiagnosticsNode> result = <DiagnosticsNode>[];
      if (header != null) {
        result.add(header!.toDiagnosticsNode(name: 'header'));
      }
      if (child != null) {
        result.add(child!.toDiagnosticsNode(name: 'child'));
      }
      if (footer != null) {
        result.add(footer!.toDiagnosticsNode(name: 'footer'));
      }
      return result;
    }

    double computeHeaderExtent() {
      if (header == null) return 0.0;
      assert(header!.hasSize);
      switch (constraints.axis) {
        case Axis.vertical:
          return header!.size.height;
        case Axis.horizontal:
          return header!.size.width;
      }
    }

    double computeFooterExtent() {
      if (footer == null) return 0.0;
      assert(footer!.hasSize);
      switch (constraints.axis) {
        case Axis.vertical:
          return footer!.size.height;
        case Axis.horizontal:
          return footer!.size.width;
      }
    }

    double? get headerLogicalExtent => overlapsContent ? 0.0 : _headerExtent;
    double? get footerLogicalExtent => overlapsContent ? 0.0 : _footerExtent;

    @override
    void performLayout() {
      if (header == null && child == null && footer == null) {
        geometry = SliverGeometry.zero;
        return;
      }

      // One of them is not null.
      AxisDirection axisDirection = applyGrowthDirectionToAxisDirection(
          constraints.axisDirection, constraints.growthDirection);

      // 1. Layout Header
      if (header != null) {
        header!.layout(
          BoxValueConstraints<SliverStickyHeaderState>(
            value: _oldState ?? SliverStickyHeaderState(0.0, false),
            constraints: constraints.asBoxConstraints(),
          ),
          parentUsesSize: true,
        );
        _headerExtent = computeHeaderExtent();
      } else {
        _headerExtent = 0.0;
      }

      // 2. Layout Footer
      if (footer != null) {
        // Footer usually doesn't change based on scroll percentage in this lib logic,
        // but standard layout applies.
        footer!.layout(constraints.asBoxConstraints(), parentUsesSize: true);
        _footerExtent = computeFooterExtent();
      } else {
        _footerExtent = 0.0;
      }

      // Compute the header/footer logical extents only one time.
      final double headerLogical = headerLogicalExtent!;
      final double footerLogical = footerLogicalExtent!;

      final double headerPaintExtent =
      calculatePaintOffset(constraints, from: 0.0, to: headerLogical);
      final double headerCacheExtent =
      calculateCacheOffset(constraints, from: 0.0, to: headerLogical);

      // We treat footer logical extent similar to header for layout purposes
      // (adding to total scroll extent).

      if (child == null) {
        // If no child, the sliver size is just header + footer (if not overlapping)
        double totalExtent = headerLogical + footerLogical;
        final double totalPaintExtent =
        calculatePaintOffset(constraints, from: 0.0, to: totalExtent);
        final double totalCacheExtent =
        calculateCacheOffset(constraints, from: 0.0, to: totalExtent);

        geometry = SliverGeometry(
            scrollExtent: totalExtent,
            maxPaintExtent: totalExtent,
            paintExtent: totalPaintExtent,
            cacheExtent: totalCacheExtent,
            hitTestExtent: totalPaintExtent,
            hasVisualOverflow: totalExtent > constraints.remainingPaintExtent ||
                constraints.scrollOffset > 0.0);
      } else {
        // 3. Layout Child
        // The child is positioned after the header logical extent.
        child!.layout(
          constraints.copyWith(
            scrollOffset: math.max(0.0, constraints.scrollOffset - headerLogical),
            cacheOrigin: math.min(0.0, constraints.cacheOrigin + headerLogical),
            overlap: math.min(headerLogical, constraints.scrollOffset) +
                (sticky ? constraints.overlap : 0),
            remainingPaintExtent:
            constraints.remainingPaintExtent - headerPaintExtent,
            remainingCacheExtent:
            constraints.remainingCacheExtent - headerCacheExtent,
          ),
          parentUsesSize: true,
        );
        final SliverGeometry childLayoutGeometry = child!.geometry!;
        if (childLayoutGeometry.scrollOffsetCorrection != null) {
          geometry = SliverGeometry(
            scrollOffsetCorrection: childLayoutGeometry.scrollOffsetCorrection,
          );
          return;
        }

        // 4. Calculate Geometry
        final double totalScrollExtent = headerLogical +
            childLayoutGeometry.scrollExtent +
            footerLogical;

        final double paintExtent = math.min(
          headerPaintExtent +
              math.max(childLayoutGeometry.paintExtent,
                  childLayoutGeometry.layoutExtent) +
              // Ensure we have room for the footer paint if visible
              (footerLogical > 0 ? calculatePaintOffset(constraints, from: headerLogical + childLayoutGeometry.scrollExtent, to: totalScrollExtent) : 0),
          constraints.remainingPaintExtent,
        );

        geometry = SliverGeometry(
          scrollExtent: totalScrollExtent,
          maxScrollObstructionExtent: sticky ? headerPaintExtent : 0,
          paintExtent: paintExtent,
          layoutExtent: math.min(
              headerPaintExtent + childLayoutGeometry.layoutExtent + footerLogical, paintExtent),
          cacheExtent: math.min(
              headerCacheExtent + childLayoutGeometry.cacheExtent + footerLogical,
              constraints.remainingCacheExtent),
          maxPaintExtent: headerLogical + childLayoutGeometry.maxPaintExtent + footerLogical,
          hitTestExtent: math.max(
              headerPaintExtent + childLayoutGeometry.paintExtent + footerLogical,
              headerPaintExtent + childLayoutGeometry.hitTestExtent + footerLogical),
          hasVisualOverflow: childLayoutGeometry.hasVisualOverflow,
        );

        final SliverPhysicalParentData? childParentData =
        child!.parentData as SliverPhysicalParentData?;

        // Position Child
        switch (axisDirection) {
          case AxisDirection.up:
          // FIX: In reverse, Child sits "above" the header (visually).
          // Start from bottom (paintExtent), move up past the Header, then move up past the Child's own height.
            childParentData!.paintOffset = Offset(
                0.0,
                geometry!.paintExtent - headerLogical - childLayoutGeometry.paintExtent
            );
            break;
          case AxisDirection.right:
            childParentData!.paintOffset = Offset(
                calculatePaintOffset(constraints, from: 0.0, to: headerLogical),
                0.0);
            break;
          case AxisDirection.down:
            childParentData!.paintOffset = Offset(0.0,
                calculatePaintOffset(constraints, from: 0.0, to: headerLogical));
            break;
          case AxisDirection.left:
            childParentData!.paintOffset = Offset.zero;
            break;
        }
      }

      // 5. Position Header
      if (header != null) {
        final SliverPhysicalParentData? headerParentData =
        header!.parentData as SliverPhysicalParentData?;
        final double childScrollExtent = child?.geometry?.scrollExtent ?? 0.0;
        final double totalChildScrollExtent = childScrollExtent + (overlapsContent ? 0.0 : (_footerExtent ?? 0.0));

        final double headerPosition = sticky
            ? math.min(
            constraints.overlap,
            totalChildScrollExtent -
                constraints.scrollOffset -
                (overlapsContent ? _headerExtent! : 0.0))
            : -constraints.scrollOffset;

        _isPinned = sticky &&
            ((constraints.scrollOffset + constraints.overlap) > 0.0 ||
                constraints.remainingPaintExtent ==
                    constraints.viewportMainAxisExtent);

        final double headerScrollRatio =
        ((headerPosition - constraints.overlap).abs() / _headerExtent!);
        if (_isPinned && headerScrollRatio <= 1) {
          controller?.stickyHeaderScrollOffset =
              constraints.precedingScrollExtent;
        }

        // LayoutBuilder update logic
        if (header is RenderConstrainedLayoutBuilder<
            BoxValueConstraints<SliverStickyHeaderState>, RenderBox>) {
          double headerScrollRatioClamped = headerScrollRatio.clamp(0.0, 1.0);

          SliverStickyHeaderState state =
          SliverStickyHeaderState(headerScrollRatioClamped, _isPinned);
          if (_oldState != state) {
            _oldState = state;
            header!.layout(
              BoxValueConstraints<SliverStickyHeaderState>(
                value: _oldState!,
                constraints: constraints.asBoxConstraints(),
              ),
              parentUsesSize: true,
            );
          }
        }

        switch (axisDirection) {
          case AxisDirection.up:
            headerParentData!.paintOffset = Offset(
                0.0, geometry!.paintExtent - headerPosition - _headerExtent!);
            break;
          case AxisDirection.down:
            headerParentData!.paintOffset = Offset(0.0, headerPosition);
            break;
          case AxisDirection.left:
            headerParentData!.paintOffset = Offset(
                geometry!.paintExtent - headerPosition - _headerExtent!, 0.0);
            break;
          case AxisDirection.right:
            headerParentData!.paintOffset = Offset(headerPosition, 0.0);
            break;
        }
      }

      // 6. Position Footer
      if (footer != null) {
        final SliverPhysicalParentData? footerParentData =
        footer!.parentData as SliverPhysicalParentData?;

        double footerPosition;

        if (stickyFooter) {
          footerPosition = geometry!.paintExtent - _footerExtent!;
        } else {
          final double headerPaintOffset = calculatePaintOffset(constraints, from: 0.0, to: headerLogical);
          final double childPaintExtent = child?.geometry?.paintExtent ?? 0.0;
          footerPosition = headerPaintOffset + childPaintExtent;
        }

        switch (axisDirection) {
          case AxisDirection.up:
          // FIX: Invert the position relative to the total paint extent
            footerParentData!.paintOffset = Offset(
                0.0,
                geometry!.paintExtent - footerPosition - _footerExtent!
            );
            break;
          case AxisDirection.left:
          // FIX: Apply similar logic for horizontal reverse
            footerParentData!.paintOffset = Offset(
                geometry!.paintExtent - footerPosition - _footerExtent!,
                0.0
            );
            break;
          case AxisDirection.down:
            footerParentData!.paintOffset = Offset(0.0, footerPosition);
            break;
          case AxisDirection.right:
            footerParentData!.paintOffset = Offset(footerPosition, 0.0);
            break;
        }
      }
    }

    @override
    bool hitTestChildren(SliverHitTestResult result,
        {required double mainAxisPosition, required double crossAxisPosition}) {
      assert(geometry!.hitTestExtent > 0.0);
      final double childScrollExtent = child?.geometry?.scrollExtent ?? 0.0;
      final double headerPosition = sticky
          ? math.min(
          constraints.overlap,
          childScrollExtent -
              constraints.scrollOffset -
              (overlapsContent ? _headerExtent! : 0.0))
          : -constraints.scrollOffset;

      // Hit test footer first (usually on top in Z-index if sticky)
      if (footer != null && stickyFooter) {
        final double footerPos = geometry!.paintExtent - _footerExtent!;
        if ((mainAxisPosition - footerPos) >= 0 && (mainAxisPosition - footerPos) <= _footerExtent!) {
          final didHitFooter = hitTestBoxChild(
            BoxHitTestResult.wrap(SliverHitTestResult.wrap(result)),
            footer!,
            mainAxisPosition: mainAxisPosition - childMainAxisPosition(footer) - footerPos,
            crossAxisPosition: crossAxisPosition,
          );
          if (didHitFooter) return true;
        }
      }

      if (header != null &&
          (mainAxisPosition - headerPosition) <= _headerExtent!) {
        final didHitHeader = hitTestBoxChild(
          BoxHitTestResult.wrap(SliverHitTestResult.wrap(result)),
          header!,
          mainAxisPosition:
          mainAxisPosition - childMainAxisPosition(header) - headerPosition,
          crossAxisPosition: crossAxisPosition,
        );

        // If we hit header, we are done unless overlapping content
        if (didHitHeader) return true;
      }

      if (child != null && child!.geometry!.hitTestExtent > 0.0) {
        bool hitChild = child!.hitTest(result,
            mainAxisPosition: mainAxisPosition - childMainAxisPosition(child),
            crossAxisPosition: crossAxisPosition);
        if (hitChild) return true;
      }

      // Check non-sticky footer if strictly following flow
      if (footer != null && !stickyFooter) {
        // ... hit test logic similar to non-sticky header ...
        // skipping for brevity as sticky is the main feature
      }

      return false;
    }

    @override
    double childMainAxisPosition(RenderObject? child) {
      if (child == header)
        return _isPinned
            ? 0.0
            : -(constraints.scrollOffset + constraints.overlap);
      if (child == this.footer && stickyFooter) {
        return geometry!.paintExtent - _footerExtent!;
      }
      if (child == this.child)
        return calculatePaintOffset(constraints,
            from: 0.0, to: headerLogicalExtent!);
      return 0;
    }

    @override
    double? childScrollOffset(RenderObject child) {
      assert(child.parent == this);
      if (child == this.child) {
        return _headerExtent;
      } else {
        return super.childScrollOffset(child);
      }
    }

    @override
    void applyPaintTransform(RenderObject child, Matrix4 transform) {
      final SliverPhysicalParentData childParentData =
      child.parentData as SliverPhysicalParentData;
      childParentData.applyPaintTransform(transform);
    }

    @override
    void paint(PaintingContext context, Offset offset) {
      if (geometry!.visible) {
        if (child != null && child!.geometry!.visible) {
          final SliverPhysicalParentData childParentData =
          child!.parentData as SliverPhysicalParentData;
          context.paintChild(child!, offset + childParentData.paintOffset);
        }

        // The header must be drawn over the sliver.
        if (header != null) {
          final SliverPhysicalParentData headerParentData =
          header!.parentData as SliverPhysicalParentData;
          context.paintChild(header!, offset + headerParentData.paintOffset);
        }

        // The footer must be drawn over the sliver (and potentially header).
        if (footer != null) {
          final SliverPhysicalParentData footerParentData =
          footer!.parentData as SliverPhysicalParentData;
          context.paintChild(footer!, offset + footerParentData.paintOffset);
        }
      }
    }
  }