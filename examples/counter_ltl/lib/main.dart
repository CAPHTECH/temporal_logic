import 'dart:async'; // Required for StreamController

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Import necessary packages
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as tlf;

// --- State Management (Riverpod) ---

// 1. Counter Notifier Provider
final counterProvider = NotifierProvider<CounterNotifier, int>(() {
  return CounterNotifier();
});

// Modified CounterNotifier to expose its own stream
class CounterNotifier extends Notifier<int> {
  // Controller to manage the stream
  late final StreamController<int> _controller;
  // Public stream getter
  late final Stream<int> stream;

  @override
  int build() {
    // Initialize controller and stream
    _controller = StreamController<int>.broadcast(); // Use broadcast
    stream = _controller.stream;

    // Add initial state to the stream
    const initialState = 0;
    _controller.add(initialState);

    // Close the controller when the notifier is disposed
    ref.onDispose(() {
      _controller.close();
    });

    return initialState; // Return initial state for the provider itself
  }

  void increment() {
    // Update the state provided by the Notifier
    state = state + 1;
    // Push the new state onto the stream
    _controller.add(state);
  }
}

// 2. LTL Formulas using tlf prefix for functions and extensions
// Ensure types are explicit and correct
final tlf.Formula<int> formulaCounterEventuallyHitsTwo = tlf.eventually(tlf.state<int>((count) => count == 2));
final tlf.Formula<int> formulaCounterNonNegative = tlf.always(tlf.state<int>((count) => count >= 0));
final tlf.Formula<int> formulaOneImpliesEventuallyTwo = tlf.always(
  tlf.state<int>((count) => count == 1).implies(tlf.eventually(tlf.state<int>((count) => count == 2))),
);

// --- App Setup ---

void main() {
  // Wrap the entire app in a ProviderScope
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter LTL Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Counter LTL Example'),
    );
  }
}

// --- UI ---

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the counter state for direct display
    final count = ref.watch(counterProvider);
    // Get the stream directly from the notifier
    final counterStream = ref.watch(counterProvider.notifier).stream;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20), // Add some spacing
            // Directly use the stream with LtlCheckerWidget
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Always Non-Negative: '),
                tlf.LtlCheckerWidget<int>(
                  stream: counterStream,
                  formula: formulaCounterNonNegative,
                  initialValue: ref.read(counterProvider),
                  builder:
                      (context, result) => Tooltip(
                        message: result ? 'Always Non-Negative holds' : 'Always Non-Negative fails',
                        child: Icon(
                          result ? Icons.check_circle : Icons.cancel,
                          color: result ? Colors.green : Colors.red,
                        ),
                      ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Eventually Hits Two: '),
                tlf.LtlCheckerWidget<int>(
                  stream: counterStream,
                  formula: formulaCounterEventuallyHitsTwo,
                  initialValue: ref.read(counterProvider),
                  builder:
                      (context, result) => Tooltip(
                        message: result ? 'Eventually hits two' : 'Did not hit two',
                        child: Icon(
                          result ? Icons.check_circle : Icons.cancel,
                          color: result ? Colors.green : Colors.red,
                        ),
                      ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('One Implies Eventually Two: '),
                tlf.LtlCheckerWidget<int>(
                  stream: counterStream,
                  formula: formulaOneImpliesEventuallyTwo,
                  initialValue: ref.read(counterProvider),
                  builder:
                      (context, result) => Tooltip(
                        message: result ? '1→2 holds' : '1→2 fails',
                        child: Icon(
                          result ? Icons.check_circle : Icons.cancel,
                          color: result ? Colors.green : Colors.red,
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterProvider.notifier).increment(),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
