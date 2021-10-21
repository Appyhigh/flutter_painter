part of 'flutter_painter.dart';

/// Flutter widget to move, scale and rotate [ObjectDrawable]s.
class ObjectWidget extends StatefulWidget {
  /// The controller for the current [FlutterPainter].
  final PainterController controller;

  /// Child widget.
  final Widget child;

  /// Whether scaling is enabled or not.
  ///
  /// If `false`, objects won't be movable, scalable or rotatable.
  final bool interactionEnabled;

  /// Creates a [ObjectWidget] with the given [controller], [child] widget..
  const ObjectWidget({
    Key? key,
    required this.controller,
    required this.child,
    this.interactionEnabled = true,
  }) : super(key: key);

  @override
  ObjectWidgetState createState() => ObjectWidgetState();
}

class ObjectWidgetState extends State<ObjectWidget> {
  static Set<double> assistAngles = <double>{
    0,
    pi / 4,
    pi / 2,
    3 * pi / 4,
    pi,
    5 * pi / 4,
    3 * pi / 2,
    7 * pi / 4,
    2 * pi
  };

  static double get objectPadding => 25;
  static Duration get controlsTransitionDuration => Duration(milliseconds: 100);

  double get controlsSize => settings.enlargeControls() ? 20 : 10;

  /// Keeps track of the selected object drawable.
  ///
  /// This is used to display controls for scale and rotation of the object.
  int? selectedDrawableIndex;

  /// Keeps track of the initial local focal point when scaling starts.
  ///
  /// This is used to offset the movement of the drawable correctly.
  Map<int, Offset> drawableInitialLocalFocalPoints = {};

  /// Keeps track of the initial drawable when scaling starts.
  ///
  /// This is used to calculate the new rotation angle and
  /// degree relative to the initial drawable.
  Map<int, ObjectDrawable> initialScaleDrawables = {};

  /// Keeps track of widgets that have assist lines assigned to them.
  ///
  /// This is used to provide haptic feedback when the assist line appears.
  Map<ObjectDrawableAssist, Set<int>> assistDrawables = Map.fromIterable(
      ObjectDrawableAssist.values,
      key: (e) => e,
      value: (e) => <int>{});

  /// Keeps track of which controls are being used.
  ///
  /// Used to highlight the controls when they are in use.
  Map<int, bool> controlsAreActive = Map.fromIterable(
    List.generate(8, (index) => index),
    key: (e) => e,
    value: (e) => false,
  );

  /// Getter for the list of [ObjectDrawable]s in the controller
  /// to make code more readable.
  List<ObjectDrawable> get drawables =>
      widget.controller.value.drawables.whereType<ObjectDrawable>().toList();

  @override
  Widget build(BuildContext context) {

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onBackgroundTapped,
              child: widget.child
            )
          ),
          ...drawables.asMap().entries.map((entry) {
            final drawable = entry.value;
            final selected = entry.key == selectedDrawableIndex;
            final size = drawable.getSize(maxWidth: constraints.maxWidth);
            // print("Container Size $size ${constraints.maxWidth}");
            final widget = Padding(
              padding: EdgeInsets.all(objectPadding),
              child: Container(
                width: size.width,
                height: size.height,
              ),
            );
            return Positioned(
              // Offset the position by half the size of the drawable so that
              // the object is in the center point
              top: drawable.position.dy - objectPadding - size.height / 2,
              left: drawable.position.dx - objectPadding - size.width / 2,
              child: Transform.rotate(
                angle: drawable.rotationAngle,
                transformHitTests: true,
                child: Container(
                  child: freeStyleSettings.enabled
                      ? widget
                      : MouseRegion(
                          cursor: SystemMouseCursors.allScroll,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => tapDrawable(drawable),
                            onScaleStart: (details) =>
                                onDrawableScaleStart(entry, details),
                            onScaleUpdate: (details) =>
                                onDrawableScaleUpdate(entry, details),
                            onScaleEnd: (_) => onDrawableScaleEnd(entry),

                            child: AnimatedSwitcher(
                              duration: controlsTransitionDuration,
                              child: selected ? Stack(
                                children: [
                                  widget,
                                  Positioned(
                                    top: objectPadding - (controlsSize/2),
                                    bottom: objectPadding - (controlsSize/2),
                                    left: objectPadding - (controlsSize/2),
                                    right: objectPadding - (controlsSize/2),
                                    child: Container(
                                      decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.white,
                                          ),
                                          boxShadow: [
                                            BorderBoxShadow(
                                              color: Colors.black,
                                              blurRadius: 2,
                                            )
                                          ]
                                      ),
                                    ),
                                  ),
                                  if(settings.showScaleRotationControls())
                                    ...[
                                      Positioned(
                                        top: objectPadding - (controlsSize),
                                        left: objectPadding - (controlsSize),
                                        width: controlsSize,
                                        height: controlsSize,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.resizeUpLeft,
                                          child: GestureDetector(
                                            onPanStart: (details) => onScaleControlPanStart(0, entry, details),
                                            onPanUpdate: (details) => onScaleControlPanUpdate(entry, details, constraints, true),
                                            onPanEnd: (details) => onScaleControlPanEnd(0, entry, details),
                                            child: _ObjectControlBox(active: controlsAreActive[0] ?? false,),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: objectPadding - (controlsSize),
                                        left: objectPadding - (controlsSize),
                                        width: controlsSize,
                                        height: controlsSize,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.resizeDownLeft,
                                          child: GestureDetector(
                                            onPanStart: (details) => onScaleControlPanStart(1, entry, details),
                                            onPanUpdate: (details) => onScaleControlPanUpdate(entry, details, constraints, true),
                                            onPanEnd: (details) => onScaleControlPanEnd(1, entry, details),
                                            child: _ObjectControlBox(active: controlsAreActive[1] ?? false,),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: objectPadding - (controlsSize),
                                        right: objectPadding - (controlsSize),
                                        width: controlsSize,
                                        height: controlsSize,
                                        child: MouseRegion(
                                          cursor: initialScaleDrawables.containsKey(entry.key) ?
                                          SystemMouseCursors.grabbing :
                                          SystemMouseCursors.grab,
                                          child: GestureDetector(
                                            onPanStart: (details) => onRotationControlPanStart(2, entry, details),
                                            onPanUpdate: (details) => onRotationControlPanUpdate(entry, details, size),
                                            onPanEnd: (details) => onRotationControlPanEnd(2, entry, details),
                                            child: _ObjectControlBox(
                                              shape: BoxShape.circle,
                                              active: controlsAreActive[2] ?? false,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: objectPadding - (controlsSize),
                                        right: objectPadding - (controlsSize),
                                        width: controlsSize,
                                        height: controlsSize,
                                        child: MouseRegion(
                                          cursor: SystemMouseCursors.resizeDownRight,
                                          child: GestureDetector(
                                            onPanStart: (details) => onScaleControlPanStart(3, entry, details),
                                            onPanUpdate: (details) => onScaleControlPanUpdate(entry, details, constraints, false),
                                            onPanEnd: (details) => onScaleControlPanEnd(3, entry, details),
                                            child: _ObjectControlBox(active: controlsAreActive[3] ?? false,),
                                          ),
                                        ),
                                      ),
                                    ],
                                ],
                              ) : widget,
                              transitionBuilder: (child, animation){
                                return FadeTransition(opacity: animation, child: child,);
                              },
                            ),
                          ),
                        ),
                ),
              ),
            );
          }),
          // if(selectedDrawableIndex != null)
          //   ...[
          //     Positioned(
          //
          //       child: Container(
          //         decoration: BoxDecoration(
          //             border:  Border.all(
          //               color: Colors.white,
          //               width: 2,
          //             ),
          //             boxShadow: [
          //               BorderBoxShadow(
          //                 color: Colors.black,
          //                 blurRadius: 1,
          //               )
          //             ]
          //         ),
          //         width: size.width,
          //         height: size.height,
          //       ),
          //     )
          //   ]
        ],
      );
    });
  }

  /// Getter for the [ObjectSettings] from the controller to make code more readable.
  ObjectSettings get settings => widget.controller.value.settings.object;

  /// Getter for the [FreeStyleSettings] from the controller to make code more readable.
  ///
  /// This is used to disable object movement, scaling and rotation
  /// when free-style drawing is enabled.
  FreeStyleSettings get freeStyleSettings =>
      widget.controller.value.settings.freeStyle;

  /// Triggers when the user taps an empty space.
  ///
  /// Deselects the selected object drawable.
  void onBackgroundTapped(){
    setState(() {
      selectedDrawableIndex = null;
    });
  }

  /// Callback when an object is tapped.
  ///
  /// Dispatches an [ObjectDrawableNotification] that the object was tapped.
  void tapDrawable(ObjectDrawable drawable) {
    if(selectedDrawableIndex != null && drawables.length > selectedDrawableIndex! && drawables[selectedDrawableIndex!] == drawable)
      ObjectDrawableNotification(drawable, ObjectDrawableNotificationType.tapped)
          .dispatch(context);

    setState(() {
      selectedDrawableIndex = drawables.indexOf(drawable);
    });
  }

  /// Callback when the object drawable starts being moved, scaled and/or rotated.
  ///
  /// Saves the initial point of interaction and drawable to be used on update events.
  void onDrawableScaleStart(
      MapEntry<int, ObjectDrawable> entry, ScaleStartDetails details) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;
    final drawable = entry.value;

    if (index < 0) return;

    setState(() {
      selectedDrawableIndex = index;
    });

    initialScaleDrawables[index] = drawable;

    // When the gesture detector is rotated, the hit test details are not transformed with it
    // This causes events from rotated objects to behave incorrectly
    // So, a [Matrix4] is used to transform the needed event details to be consistent with
    // the current rotation of the object
    final rotateOffset = Matrix4.rotationZ(drawable.rotationAngle)
      ..translate(details.localFocalPoint.dx, details.localFocalPoint.dy)
      ..rotateZ(-drawable.rotationAngle);
    drawableInitialLocalFocalPoints[index] =
        Offset(rotateOffset[12], rotateOffset[13]);
  }

  /// Callback when the object drawable finishes movement, scaling and rotation.
  ///
  /// Cleans up the object information.
  void onDrawableScaleEnd(MapEntry<int, ObjectDrawable> entry) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;

    // Using the index instead of [entry.value] is to prevent an issue
    // when an update and end events happen before the UI is updated,
    // the [entry.value] is the old drawable before it was updated
    // This causes updating the entry in this method to sometimes fail
    // To get around it, the object is fetched directly from the drawables
    // in the controller
    final drawable = drawables[index];

    // Clean up
    drawableInitialLocalFocalPoints.remove(index);
    initialScaleDrawables.remove(index);
    for (final assistSet in assistDrawables.values) assistSet.remove(index);

    // Remove any assist lines the object has
    final newDrawable = drawable.copyWith(assists: {});

    updateDrawable(drawable, newDrawable);
  }

  /// Callback when the object drawable is moved, scaled and/or rotated.
  ///
  /// Calculates the next position, scale and rotation of the object depending on the event details.
  void onDrawableScaleUpdate(
      MapEntry<int, ObjectDrawable> entry, ScaleUpdateDetails details) {
    if (!widget.interactionEnabled) return;

    final index = entry.key;
    final drawable = entry.value;
    if (index < 0) return;

    final initialDrawable = initialScaleDrawables[index];
    // When the gesture detector is rotated, the hit test details are not transformed with it
    // This causes events from rotated objects to behave incorrectly
    // So, a [Matrix4] is used to transform the needed event details to be consistent with
    // the current rotation of the object
    final initialLocalFocalPoint =
        drawableInitialLocalFocalPoints[index] ?? Offset.zero;

    if (initialDrawable == null) return;

    final initialPosition = initialDrawable.position - initialLocalFocalPoint;
    final initialRotation = initialDrawable.rotationAngle;

    // When the gesture detector is rotated, the hit test details are not transformed with it
    // This causes events from rotated objects to behave incorrectly
    // So, a [Matrix4] is used to transform the needed event details to be consistent with
    // the current rotation of the object
    final rotateOffset = Matrix4.identity()
      ..rotateZ(initialRotation)
      ..translate(details.localFocalPoint.dx, details.localFocalPoint.dy)
      ..rotateZ(-initialRotation);
    final position =
        initialPosition + Offset(rotateOffset[12], rotateOffset[13]);

    // Calculate scale of object reference to the initial object scale
    final scale = initialDrawable.scale * details.scale;

    // Calculate the rotation of the object reference to the initial object rotation
    // and normalize it so that its between 0 and 2*pi
    var rotation = (initialRotation + details.rotation).remainder(pi * 2);
    if (rotation < 0) rotation += pi * 2;

    // The center point of the widget
    final center = this.center;

    // The angle from [assistAngles] the object's current rotation is close
    final double? closestAssistAngle;

    // If layout assist is enabled, calculate the positional and rotational assists
    if (settings.layoutAssist.enabled) {
      calculatePositionalAssists(
        settings.layoutAssist,
        index,
        position,
        center,
      );
      closestAssistAngle = calculateRotationalAssist(
        settings.layoutAssist,
        index,
        rotation,
      );
    } else {
      closestAssistAngle = null;
    }

    // The set of assists for the object
    // If layout assist is disabled, it is empty
    final assists = settings.layoutAssist.enabled
        ? assistDrawables.entries
            .where((element) => element.value.contains(index))
            .map((e) => e.key)
            .toSet()
        : <ObjectDrawableAssist>{};

    // Do not display the rotational assist if the user is using less that 2 pointers
    // So, rotational assist lines won't show if the user is only moving the object
    if (details.pointerCount < 2) assists.remove(ObjectDrawableAssist.rotation);

    // Snap the object to the horizontal/vertical center if its is near it
    // and layout assist is enabled
    final assistedPosition = Offset(
      assists.contains(ObjectDrawableAssist.vertical) ? center.dx : position.dx,
      assists.contains(ObjectDrawableAssist.horizontal)
          ? center.dy
          : position.dy,
    );

    // Snap the object rotation to the nearest angle from [assistAngles] if its near it
    // and layout assist is enabled
    final assistedRotation = assists.contains(ObjectDrawableAssist.rotation) &&
            closestAssistAngle != null
        ? closestAssistAngle.remainder(pi * 2)
        : rotation;

    final newDrawable = drawable.copyWith(
      position: assistedPosition,
      scale: scale,
      rotation: assistedRotation,
      assists: assists,
    );

    updateDrawable(drawable, newDrawable);
  }

  /// Calculates whether the object entered or exited the horizontal and vertical assist areas.
  void calculatePositionalAssists(ObjectLayoutAssistSettings settings,
      int index, Offset position, Offset center) {
    // Horizontal
    //
    // If the object is within the enter distance from the center dy and isn't marked
    // as a drawable with a horizontal assist, mark it
    if ((position.dy - center.dy).abs() < settings.positionalEnterDistance &&
        !(assistDrawables[ObjectDrawableAssist.horizontal]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.horizontal]?.add(index);
      settings.hapticFeedback.impact();
    }
    // Otherwise, if the object is outside the exit distance from the center dy and is marked as
    // as a drawable with a horizontal assist, un-mark it
    else if ((position.dy - center.dy).abs() >
            settings.positionalExitDistance &&
        (assistDrawables[ObjectDrawableAssist.horizontal]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.horizontal]?.remove(index);
    }

    // Vertical
    //
    // If the object is within the enter distance from the center dx and isn't marked
    // as a drawable with a vertical assist, mark it
    if ((position.dx - center.dx).abs() < settings.positionalEnterDistance &&
        !(assistDrawables[ObjectDrawableAssist.vertical]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.vertical]?.add(index);
      settings.hapticFeedback.impact();
    }
    // Otherwise, if the object is outside the exit distance from the center dx and is marked as
    // as a drawable with a vertical assist, un-mark it
    else if ((position.dx - center.dx).abs() >
            settings.positionalExitDistance &&
        (assistDrawables[ObjectDrawableAssist.vertical]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.vertical]?.remove(index);
    }
  }

  /// Calculates whether the object entered or exited the rotational assist range.
  ///
  /// Returns the angle the object is closest to if it is inside the assist range.
  double? calculateRotationalAssist(
      ObjectLayoutAssistSettings settings, int index, double rotation) {
    // Calculates all angles from [assistAngles] in the exit range of rotational assist
    final closeAngles = assistAngles
        .where(
            (angle) => (rotation - angle).abs() < settings.rotationalExitAngle)
        .toList();

    // If the object is close to at least one assist angle
    if (closeAngles.isNotEmpty) {
      // If the object is also in the enter range of rotational assist and isn't marked
      // as a drawable with a rotational assist, mark it
      if (closeAngles.any((angle) =>
              (rotation - angle).abs() < settings.rotationalEnterAngle) &&
          !(assistDrawables[ObjectDrawableAssist.rotation]?.contains(index) ??
              false)) {
        assistDrawables[ObjectDrawableAssist.rotation]?.add(index);
        settings.hapticFeedback.impact();
      }
      // Return the angle the object is close to
      return closeAngles[0];
    }

    // Otherwise, if the object is not in the exit range of any assist angles,
    // but is marked as a drawable with rotational assist, un-mark it
    if (closeAngles.isEmpty &&
        (assistDrawables[ObjectDrawableAssist.rotation]?.contains(index) ??
            false)) {
      assistDrawables[ObjectDrawableAssist.rotation]?.remove(index);
    }

    return null;
  }

  /// Returns the center point of the painter widget.
  ///
  /// Uses the [GlobalKey] for the painter from [controller].
  Offset get center {
    final renderBox = widget.controller.painterKey.currentContext
        ?.findRenderObject() as RenderBox?;
    final center = renderBox == null
        ? Offset.zero
        : Offset(
            renderBox.size.width / 2,
            renderBox.size.height / 2,
          );
    return center;
  }

  /// Replaces a drawable with a new one.
  void updateDrawable(ObjectDrawable oldDrawable, ObjectDrawable newDrawable) {
    setState(() {
      widget.controller.replaceDrawable(oldDrawable, newDrawable);
    });
  }

  void onRotationControlPanStart(int controlIndex, MapEntry<int, ObjectDrawable> entry, DragStartDetails details){
    setState(() {
      controlsAreActive[controlIndex] = true;
    });
    onDrawableScaleStart(entry, ScaleStartDetails(
      pointerCount: 2,
      localFocalPoint: entry.value.position,
    ));
  }

  void onRotationControlPanUpdate(MapEntry<int, ObjectDrawable> entry, DragUpdateDetails details, Size size){
    final index = entry.key;
    final initial = initialScaleDrawables[index];
    if(initial == null)
      return;
    final initialOffset = Offset((size.width/2), (-size.height/2));
    final initialAngle = atan2(initialOffset.dx, initialOffset.dy);
    final angle = atan2((details.localPosition.dx + initialOffset.dx), (details.localPosition.dy + initialOffset.dy));
    final rotation = initialAngle - angle;
    onDrawableScaleUpdate(entry, ScaleUpdateDetails(
      pointerCount: 2,
      rotation: rotation,
      scale: 1,
      localFocalPoint: entry.value.position,
    ));
  }

  void onRotationControlPanEnd(int controlIndex, MapEntry<int, ObjectDrawable> entry, DragEndDetails details){
    setState(() {
      controlsAreActive[controlIndex] = false;
    });
    onDrawableScaleEnd(entry);
  }

  void onScaleControlPanStart(int controlIndex, MapEntry<int, ObjectDrawable> entry, DragStartDetails details){
    setState(() {
      controlsAreActive[controlIndex] = true;
    });
    onDrawableScaleStart(entry, ScaleStartDetails(
      pointerCount: 1,
      localFocalPoint: entry.value.position,
    ));
  }

  void onScaleControlPanUpdate(
      MapEntry<int, ObjectDrawable> entry,
      DragUpdateDetails details,
      BoxConstraints constraints,[
        bool isReversed = true
      ]){
    final index = entry.key;
    final initial = initialScaleDrawables[index];
    if(initial == null)
      return;
    final length = details.localPosition.dx * (isReversed ? -1 : 1);
    final initialSize = initial.getSize(maxWidth: constraints.maxWidth);
    final initialLength = initialSize.width/2;
    final double scale = ((length + initialLength) / initialLength).clamp(0.001, double.infinity);
    onDrawableScaleUpdate(entry, ScaleUpdateDetails(
      pointerCount: 1,
      rotation: 0,
      scale: scale,
      localFocalPoint: entry.value.position,
    ));
  }

  void onScaleControlPanEnd(int controlIndex, MapEntry<int, ObjectDrawable> entry, DragEndDetails details){
    setState(() {
      controlsAreActive[controlIndex] = false;
    });
    onDrawableScaleEnd(entry);
  }

}

/// The control box container (only the UI, no logic).
class _ObjectControlBox extends StatelessWidget {
  /// Shape of the control box.
  final BoxShape shape;

  /// Whether the box is being used or not.
  final bool active;

  /// Creates an [_ObjectControlBox] with the given [shape] and [active].
  ///
  /// By default, it will be a [BoxShape.rectangle] shape and not active.
  const _ObjectControlBox({
    Key? key,
    this.shape = BoxShape.rectangle,
    this.active = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: ObjectWidgetState.controlsTransitionDuration,
      decoration: BoxDecoration(
        color: active ? Theme.of(context).accentColor : Colors.white,
        shape: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 2,
          )
        ],
      ),
    );
  }
}

/// Represents a [Notification] that [ObjectWidget] dispatches when an event occurs
/// that requires a parent to handle it.
///
/// Parent widgets can listen using a [NotificationListener] and handle the notification.
class ObjectDrawableNotification extends Notification {
  /// The drawable involved in the notification.
  final ObjectDrawable drawable;

  /// The type of event that caused this notification to trigger.
  final ObjectDrawableNotificationType type;

  /// Creates an [ObjectDrawableNotification] with the given [drawable] and [type].
  const ObjectDrawableNotification(this.drawable, this.type);
}

/// The types of events that are dispatched with an [ObjectDrawableNotification].
enum ObjectDrawableNotificationType {
  /// Represents the event of tapping an [ObjectDrawable] inside the [ObjectWidget].
  tapped,
}
