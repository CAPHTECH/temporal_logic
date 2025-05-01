import 'dart:async'; // Needed for StreamController

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Prefixed imports to potentially avoid conflicts, though less likely here
import 'package:temporal_logic_core/temporal_logic_core.dart' as temporal_core; // Hide core extensions
import 'package:temporal_logic_flutter/temporal_logic_flutter.dart' as temporal_flutter;
import 'package:temporal_logic_mtl/temporal_logic_mtl.dart' as temporal_mtl;

// --- State Management ---

// State representing whether the snackbar is visible
enum SnackbarState { visible, hidden }

// Use a Stopwatch to get timestamps relative to app start (or widget init)
// Or use DateTime.now().difference(startTime) if an absolute start time is preferred
final _stopwatch = Stopwatch()..start();

// Trigger to initiate showing the snackbar
final snackbarTriggerProvider = StateProvider<int>((ref) => 0);

// --- App Setup ---
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snackbar MTL Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Snackbar MTL'),
    );
  }
}

// --- UI ---
class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> {
  // --- Define Operands (Atomic Propositions) using state helper ---
  static final operandHidden =
      temporal_flutter.state<SnackbarState>((s) => s == SnackbarState.hidden, name: 'hidden' // Add optional name
          );

  // --- Define Time Intervals (Only for first check) ---
  static final intervalCheckDuration = temporal_mtl.TimeInterval(
    Duration.zero,
    const Duration(milliseconds: 2500), // 2.5 seconds
  );

  // Stream controller for TimedValue
  late StreamController<temporal_core.TimedValue<SnackbarState>> _snackbarStreamController;
  // Initial timed value
  late temporal_core.TimedValue<SnackbarState> _initialSnackbarState;

  @override
  void initState() {
    super.initState();
    // Use broadcast controller for multiple listeners
    _snackbarStreamController = StreamController<temporal_core.TimedValue<SnackbarState>>.broadcast();
    // Set initial state
    _initialSnackbarState = temporal_core.TimedValue(SnackbarState.hidden, _stopwatch.elapsed);
    // Add initial state to stream
    _snackbarStreamController.add(_initialSnackbarState);
  }

  @override
  void dispose() {
    _snackbarStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(snackbarTriggerProvider, (previous, next) {
      if (next > (previous ?? 0)) {
        // --- Add TimedValue when snackbar should be shown ---
        final showTime = _stopwatch.elapsed;
        _snackbarStreamController.add(temporal_core.TimedValue(SnackbarState.visible, showTime));

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final controller = ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Snackbar shown! Count: $next'),
            duration: const Duration(seconds: 2),
          ),
        );

        // --- Add TimedValue when snackbar is closed ---
        controller.closed.then((_) {
          // We don't need to check the riverpod state anymore
          // Just record that it became hidden at this time
          final hideTime = _stopwatch.elapsed;
          // Only add if controller is still active
          if (mounted && !_snackbarStreamController.isClosed) {
            _snackbarStreamController.add(temporal_core.TimedValue(SnackbarState.hidden, hideTime));
          }
        });
      }
    });

    // Watch the original trigger provider just to rebuild the Text widget if needed
    // (Alternatively, use a StreamBuilder for the current state from _snackbarStreamController)
    final currentTriggerCount = ref.watch(snackbarTriggerProvider);

    // Define the MTL formula F_[0, 2.5s] (hidden)
    final formulaEventuallyHiddenShort = temporal_mtl.EventuallyTimed(
      operandHidden,
      intervalCheckDuration,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Temporal Logic Checks on Snackbar State', // Updated title
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                  '(F: Eventually, [a,b]: time interval, Sustained(S, d): State S holds for duration d)'), // Updated legend
              const SizedBox(height: 20),
              Text('Press the button to show a snackbar (Trigger: $currentTriggerCount)'), // Show trigger count
              const SizedBox(height: 10),
              // Display current state using StreamBuilder or alternative
              StreamBuilder<temporal_core.TimedValue<SnackbarState>>(
                  stream: _snackbarStreamController.stream,
                  initialData: _initialSnackbarState, // Use initial value
                  builder: (context, snapshot) {
                    final stateName = snapshot.data?.value.name ?? 'unknown';
                    final time = snapshot.data?.timestamp ?? Duration.zero;
                    return Text('Last Tracked State: $stateName at ${time.inMilliseconds}ms');
                  }),

              const Divider(height: 40),
              // --- Check 1 Display (Now with Widget) ---
              const Text(
                'Check 1: F_[0, 2.5s] (hidden)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('Is "hidden" state reached within 2.5s of start?'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Add padding
                child: Tooltip(
                  message: 'F_[0, 2.5s] (hidden)',
                  child: temporal_flutter.MtlCheckerWidget<SnackbarState>(
                    stream: _snackbarStreamController.stream,
                    initialValue: _initialSnackbarState,
                    formula: formulaEventuallyHiddenShort,
                    builder: (context, result, details) => _genericIconBuilder(context, result, details),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // --- Check 2 Display (Now with Widget) ---
              const Text(
                'Check 2: Sustained(hidden, 1s)',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('Is "hidden" state maintained for 1s once entered?'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0), // Add padding
                child: Tooltip(
                  message: 'Sustained(hidden, 1s)',
                  child: temporal_flutter.SustainedStateCheckerWidget<SnackbarState>(
                    stream: _snackbarStreamController.stream,
                    initialValue: _initialSnackbarState,
                    targetState: SnackbarState.hidden,
                    sustainDuration: const Duration(seconds: 1),
                    builder: (context, status) =>
                        _genericIconBuilder(context, status == temporal_flutter.CheckStatus.success, status),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Increment the trigger provider
          ref.read(snackbarTriggerProvider.notifier).state++;
        },
        tooltip: 'Show Snackbar',
        child: const Icon(Icons.add_alert),
      ),
    );
  }

  // Helper for default icon builder (adaptable)
  Widget _genericIconBuilder(BuildContext context, bool result, [dynamic details]) {
    // Can add more complex logic using 'details' if it's an EvaluationResult
    String tooltip = result ? 'Check Holds' : 'Check Fails';
    if (details is temporal_core.EvaluationResult && details.reason != null) {
      tooltip = details.reason!;
    } else if (details is temporal_flutter.CheckStatus) {
      switch (details) {
        case temporal_flutter.CheckStatus.success:
          tooltip = 'State Sustained';
          break;
        case temporal_flutter.CheckStatus.failure:
          tooltip = 'State Not Sustained';
          break;
        case temporal_flutter.CheckStatus.pending:
          tooltip = 'Sustained Check Pending';
          break;
      }
    }

    IconData icon;
    Color color;
    if (details is temporal_flutter.CheckStatus) {
      switch (details) {
        case temporal_flutter.CheckStatus.success:
          icon = Icons.check_circle;
          color = Colors.green;
          break;
        case temporal_flutter.CheckStatus.failure:
          icon = Icons.cancel;
          color = Colors.red;
          break;
        case temporal_flutter.CheckStatus.pending:
          icon = Icons.hourglass_empty;
          color = Colors.orange;
          break;
      }
    } else {
      icon = result ? Icons.check_circle : Icons.cancel;
      color = result ? Colors.green : Colors.red;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color),
    );
  }
}
