import 'package:flutter/material.dart';

/// Default transition duration
const Duration _defaultDuration = Duration(milliseconds: 350);

/// Enum to pick transition type
enum ScreenTransition {
  fade,
  slideRightToLeft,
  slideLeftToRight,
  slideFade,
  scale,
  rotate,
}

/// Slide from right to left
RouteTransitionsBuilder slideRightToLeft = (context, animation, _, child) {
  final offsetTween =
      Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
  return SlideTransition(
    position:
        animation.drive(CurveTween(curve: Curves.easeInOut)).drive(offsetTween),
    child: child,
  );
};

/// Slide from left to right
RouteTransitionsBuilder slideLeftToRight = (context, animation, _, child) {
  final offsetTween =
      Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero);
  return SlideTransition(
    position:
        animation.drive(CurveTween(curve: Curves.easeInOut)).drive(offsetTween),
    child: child,
  );
};

/// Slide from bottom + fade
RouteTransitionsBuilder slideFadeFromBottom = (context, animation, _, child) {
  final slideTween = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero);
  final fadeTween = Tween<double>(begin: 0.0, end: 1.0);
  return SlideTransition(
    position:
        animation.drive(CurveTween(curve: Curves.easeOut)).drive(slideTween),
    child: FadeTransition(
      opacity:
          animation.drive(CurveTween(curve: Curves.easeIn)).drive(fadeTween),
      child: child,
    ),
  );
};

/// Scale (zoom in)
RouteTransitionsBuilder scaleIn = (context, animation, _, child) {
  return ScaleTransition(
    scale: animation.drive(CurveTween(curve: Curves.fastOutSlowIn)),
    child: child,
  );
};

/// Rotate + fade
RouteTransitionsBuilder rotateFade = (context, animation, _, child) {
  return RotationTransition(
    turns: animation,
    child: FadeTransition(opacity: animation, child: child),
  );
};

/// Fade transition (default)
RouteTransitionsBuilder fadeIn = (context, animation, _, child) {
  return FadeTransition(
    opacity: animation,
    child: child,
  );
};

/// Returns the right transition builder
RouteTransitionsBuilder _getTransitionBuilder(ScreenTransition? transition) {
  switch (transition) {
    case ScreenTransition.slideRightToLeft:
      return slideRightToLeft;
    case ScreenTransition.slideLeftToRight:
      return slideLeftToRight;
    case ScreenTransition.slideFade:
      return slideFadeFromBottom;
    case ScreenTransition.scale:
      return scaleIn;
    case ScreenTransition.rotate:
      return rotateFade;
    case ScreenTransition.fade:
    default:
      return fadeIn;
  }
}

/// Push screen with custom animation
void nextScreen(BuildContext context, Widget screen,
    {ScreenTransition? transition}) {
  Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: _defaultDuration,
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: _getTransitionBuilder(transition),
    ),
  );
}

/// Replace screen with custom animation
void nextScreenReplacement(BuildContext context, Widget screen,
    {ScreenTransition? transition}) {
  Navigator.pushReplacement(
    context,
    PageRouteBuilder(
      transitionDuration: _defaultDuration,
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: _getTransitionBuilder(transition),
    ),
  );
}
