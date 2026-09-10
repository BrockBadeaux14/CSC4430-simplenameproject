# simplenameproject

A Flutter counter with gravity: the message, count, and increment button fall,
bounce off the window edges, and collide with each other. Drag an element to
pick it up, then release to toss it. The reset icon drops the elements again
without clearing the count.

On macOS, moving the app window also moves the elements through inertia. Run
with `flutter run -d macos`. Stop and run the app again after native Swift
changes; hot reload and hot restart do not reload the native window integration.
Other platforms support gravity and direct dragging, but do not receive native
window movement events.

Run `flutter test` for physics, interaction, resize, and motion-channel checks,
and `flutter analyze` for static analysis.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
