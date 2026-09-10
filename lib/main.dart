import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'gravity_simulation.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  static const _message = 'Brock has pushed the button this many times:';
  static const _messageStyle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );
  static const _motionChannel = EventChannel('simplenameproject/window_motion');
  final _simulation = GravitySimulation();
  final _windowMotion = WindowMotion();
  final _repaint = ValueNotifier<int>(0);
  late final Ticker _ticker;
  StreamSubscription<dynamic>? _motionSubscription;
  Duration? _lastTick;
  int _counter = 0;

  bool get _supportsWindowMotion =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    if (_supportsWindowMotion) {
      _motionSubscription = _motionChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          final sample = event as List<dynamic>;
          final impulse = _windowMotion.sample(
            Offset(
              (sample[0] as num).toDouble(),
              (sample[1] as num).toDouble(),
            ),
            (sample[2] as num).toDouble(),
          );
          _simulation.applyImpulse(impulse);
        },
        onError: (Object error) {
          // Gravity and direct manipulation still work if the native stream fails.
          debugPrint('Window motion unavailable: $error');
        },
      );
    }
  }

  void _tick(Duration elapsed) {
    final previous = _lastTick;
    _lastTick = elapsed;
    if (previous == null) return;
    _simulation.advance((elapsed - previous).inMicroseconds / 1000000);
    _repaint.value++;
  }

  @override
  void dispose() {
    _motionSubscription?.cancel();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() => _counter++);
  }

  Widget _element(int index, Widget child) {
    final body = _simulation.bodies[index];
    return Positioned(
      left: body.position.dx,
      top: body.position.dy,
      width: body.size.width,
      height: body.size.height,
      child: MouseRegion(
        cursor: body.held
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: GestureDetector(
          key: ValueKey('gravity-element-$index'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) {
            body.held = true;
            body.velocity = Offset.zero;
          },
          onPanUpdate: (details) {
            body.position += details.delta;
            _simulation.contain(body);
            _repaint.value++;
          },
          onPanEnd: (details) {
            body.held = false;
            body.velocity = limitSpeed(details.velocity.pixelsPerSecond, 1800);
          },
          onPanCancel: () => body.held = false,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Drop elements again',
            onPressed: () {
              _simulation.reset();
              _repaint.value++;
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _supportsWindowMotion
                    ? 'Move the window to shake things up. Grab and toss any element.'
                    : 'Gravity is on. Grab and toss any element.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bounds = constraints.biggest;
                    if (bounds.isEmpty) return const SizedBox.shrink();
                    final messageWidth = math.min(620.0, bounds.width);
                    final painter = TextPainter(
                      text: const TextSpan(
                        text: _message,
                        style: _messageStyle,
                      ),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                    )..layout(maxWidth: math.max(1, messageWidth - 32));
                    final messageHeight = math.min(
                      bounds.height,
                      painter.height + 32,
                    );
                    painter.dispose();
                    _simulation.layout(bounds, [
                      Size(messageWidth, messageHeight),
                      Size(
                        math.min(88, bounds.width),
                        math.min(80, bounds.height),
                      ),
                      Size(
                        math.min(56, bounds.width),
                        math.min(56, bounds.height),
                      ),
                    ]);
                    return ClipRect(
                      child: AnimatedBuilder(
                        animation: _repaint,
                        builder: (context, _) => Stack(
                          fit: StackFit.expand,
                          children: [
                            _element(
                              0,
                              Material(
                                color: colors.surfaceContainerLow,
                                elevation: 2,
                                borderRadius: BorderRadius.circular(18),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: math.max(1, messageWidth - 32),
                                      child: const Text(
                                        _message,
                                        textAlign: TextAlign.center,
                                        style: _messageStyle,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _element(
                              1,
                              Material(
                                color: colors.primaryContainer,
                                elevation: 3,
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$_counter',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: colors.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _element(
                              2,
                              FloatingActionButton(
                                onPressed: _incrementCounter,
                                tooltip: 'Increment',
                                child: const Icon(Icons.add),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
