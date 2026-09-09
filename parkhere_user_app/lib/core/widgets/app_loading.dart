import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppLoading extends StatefulWidget {
  final bool partner;
  const AppLoading({super.key, this.partner = false});

  @override
  State<AppLoading> createState() => _AppLoadingState();
}

class _AppLoadingState extends State<AppLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = .5;
    } else {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.partner
        ? 'Preparando sua gestão…'
        : 'Preparando seu caminho…';
    return Center(
      child: Semantics(
        label: label,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 100,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => widget.partner
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.storefront, size: 48),
                          const SizedBox(width: 18),
                          for (var i = 0; i < 3; i++)
                            Padding(
                              padding: const EdgeInsets.all(3),
                              child: Container(
                                width: 15,
                                height:
                                    25 +
                                    35 *
                                        (.5 +
                                            .5 *
                                                math.sin(
                                                  _controller.value *
                                                          math.pi *
                                                          2 +
                                                      i,
                                                )),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                        ],
                      )
                    : ClipRect(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Positioned(
                              bottom: 22,
                              left: 0,
                              right: 0,
                              child: Divider(thickness: 2),
                            ),
                            Positioned(
                              left: -48 + 336 * _controller.value,
                              bottom: 26,
                              child: Icon(
                                Icons.directions_car_filled,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Text(label),
          ],
        ),
      ),
    );
  }
}
