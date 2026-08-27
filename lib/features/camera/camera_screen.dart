import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/providers.dart';
import '../../core/design/tokens.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/widgets/brand.dart';
import '../challenge/models.dart';
import 'pending_upload_store.dart';
import 'live_look_processor.dart';

enum CaptureStage {
  explanation,
  ready,
  countdown,
  recording,
  processing,
  queued,
  done,
  failed,
}

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});
  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = const [];
  int cameraIndex = 0;
  CaptureStage stage = CaptureStage.explanation;
  int countdown = 3;
  double progress = 0;
  String look = 'Natural';
  String? errorMessage;
  TakeAttempt? attempt;
  Timer? progressTimer;
  final stopwatch = Stopwatch();

  static const freeLooks = [
    'Natural',
    'Black & White',
    'Warm Film',
    'Cool',
    'Grain',
    'Retro',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    progressTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (stage == CaptureStage.recording && state != AppLifecycleState.resumed) {
      _technicalFailure('app_backgrounded');
    }
  }

  Future<void> _enableCamera() async {
    final statuses = await [Permission.camera, Permission.microphone].request();
    if (statuses.values.any((status) => !status.isGranted)) {
      setState(() {
        stage = CaptureStage.failed;
        errorMessage =
            'Camera and microphone access are required for a direct take.';
      });
      return;
    }
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) throw StateError('No camera is available.');
      final front = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      cameraIndex = front >= 0 ? front : 0;
      await _initialize(cameraIndex);
      if (mounted) setState(() => stage = CaptureStage.ready);
    } catch (error) {
      setState(() {
        stage = CaptureStage.failed;
        errorMessage = ErrorMapper.message(error);
      });
    }
  }

  Future<void> _initialize(int index) async {
    await controller?.dispose();
    final next = CameraController(
      cameras[index],
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );
    controller = next;
    await next.initialize();
    await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
  }

  Future<void> _flip() async {
    if (stage != CaptureStage.ready || cameras.length < 2) return;
    final next = (cameraIndex + 1) % cameras.length;
    setState(() => stage = CaptureStage.processing);
    try {
      await _initialize(next);
      cameraIndex = next;
      if (mounted) setState(() => stage = CaptureStage.ready);
    } catch (error) {
      if (mounted) {
        setState(() {
          stage = CaptureStage.failed;
          errorMessage = ErrorMapper.message(error);
        });
      }
    }
  }

  Future<void> _capture() async {
    if (stage != CaptureStage.ready ||
        controller?.value.isInitialized != true) {
      return;
    }
    try {
      attempt = await ref.read(appRepositoryProvider).issueAttempt();
      setState(() {
        stage = CaptureStage.countdown;
        countdown = 3;
      });
      for (var value = 3; value > 0; value--) {
        if (!mounted) return;
        setState(() => countdown = value);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      await ref.read(appRepositoryProvider).markAttemptStarted(attempt!.id);
      await controller!.startVideoRecording();
      stopwatch
        ..reset()
        ..start();
      setState(() {
        stage = CaptureStage.recording;
        progress = 0;
      });
      progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) {
          setState(
            () => progress = math.min(1, stopwatch.elapsedMilliseconds / 7000),
          );
        }
      });
      await Future<void>.delayed(const Duration(seconds: 7));
      if (stage != CaptureStage.recording) return;
      final file = await controller!.stopVideoRecording();
      stopwatch.stop();
      progressTimer?.cancel();
      final duration = stopwatch.elapsedMilliseconds;
      if (duration < 6800 || duration > 7600) {
        await _technicalFailure('duration_out_of_tolerance');
        return;
      }
      setState(() => stage = CaptureStage.processing);
      final rawFile = File(file.path);
      final processed = await LiveLookProcessor.burn(
        source: rawFile,
        attemptId: attempt!.id,
        look: look,
      );
      final bytes = await processed.file.readAsBytes();
      var uploaded = false;
      try {
        await ref
            .read(appRepositoryProvider)
            .finalizeTake(
              attempt: attempt!,
              videoBytes: bytes,
              durationMs: duration,
              look: look,
            );
        uploaded = true;
      } catch (_) {
        await PendingUploadStore.persist(
          source: processed.file,
          attempt: attempt!,
          durationMs: duration,
          look: look,
        );
      }
      try {
        await rawFile.delete();
      } on FileSystemException {
        // The camera plugin may already have reclaimed its temporary source.
      }
      ref.invalidate(hasTakeTodayProvider);
      ref.invalidate(currentChallengeProvider);
      if (mounted) {
        setState(
          () => stage = uploaded ? CaptureStage.done : CaptureStage.queued,
        );
      }
    } catch (error) {
      await _technicalFailure('camera_or_recording_error');
      if (mounted) {
        setState(() => errorMessage = ErrorMapper.message(error));
      }
    }
  }

  Future<void> _technicalFailure(String reason) async {
    progressTimer?.cancel();
    stopwatch.stop();
    if (controller?.value.isRecordingVideo == true) {
      try {
        await controller!.stopVideoRecording();
      } catch (_) {}
    }
    final currentAttempt = attempt;
    if (currentAttempt != null) {
      try {
        await ref
            .read(appRepositoryProvider)
            .requestTechnicalRetry(
              attemptId: currentAttempt.id,
              reason: reason,
              diagnostics: {
                'camera': cameras.isEmpty
                    ? 'unknown'
                    : cameras[cameraIndex].name,
                'elapsed_ms': stopwatch.elapsedMilliseconds,
                'app_state': WidgetsBinding.instance.lifecycleState?.name,
              },
            );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        stage = CaptureStage.failed;
        errorMessage ??= 'A verified technical problem interrupted the take.';
      });
    }
  }

  List<double> _filterMatrix() => switch (look) {
    'Black & White' => const [
      .33,
      .33,
      .33,
      0,
      0,
      .33,
      .33,
      .33,
      0,
      0,
      .33,
      .33,
      .33,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ],
    'Warm Film' => const [
      1.08,
      0,
      0,
      0,
      8,
      0,
      1.02,
      0,
      0,
      2,
      0,
      0,
      .92,
      0,
      -4,
      0,
      0,
      0,
      1,
      0,
    ],
    'Cool' => const [
      .94,
      0,
      0,
      0,
      -2,
      0,
      1.01,
      0,
      0,
      1,
      0,
      0,
      1.08,
      0,
      7,
      0,
      0,
      0,
      1,
      0,
    ],
    'Retro' => const [
      1.05,
      .03,
      0,
      0,
      5,
      .02,
      .96,
      0,
      0,
      0,
      0,
      .02,
      .82,
      0,
      3,
      0,
      0,
      0,
      1,
      0,
    ],
    _ => const [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: switch (stage) {
      CaptureStage.explanation => _permissionExplanation(),
      CaptureStage.failed => _failure(),
      CaptureStage.done => _done(),
      CaptureStage.queued => _queued(),
      _ => _cameraView(),
    },
  );

  Widget _queued() => SafeArea(
    minimum: const EdgeInsets.all(24),
    child: Column(
      children: [
        IconButton(onPressed: context.pop, icon: const Icon(Icons.close)),
        const Spacer(),
        const Icon(
          Icons.cloud_upload_outlined,
          size: 72,
          color: SvnlyColors.lime,
        ),
        const SizedBox(height: 24),
        Text('Take saved', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        const Text(
          'Your take is protected on this iPhone and will upload automatically when SVNLY starts with a connection. The feed unlocks after that upload finishes.',
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton(
          onPressed: context.pop,
          child: const Text('BACK TO TODAY'),
        ),
      ],
    ),
  );

  Widget _permissionExplanation() => SafeArea(
    minimum: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(onPressed: context.pop, icon: const Icon(Icons.close)),
        const Spacer(),
        const Icon(Icons.videocam_outlined, size: 64, color: SvnlyColors.lime),
        const SizedBox(height: 24),
        Text(
          'Your camera. Your moment.',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        const Text(
          'SVNLY needs camera and microphone access only when you record. Gallery uploads are never available. Recording starts after 3–2–1 and stops automatically after exactly seven seconds.',
        ),
        const SizedBox(height: 24),
        const RuleChips(),
        const Spacer(),
        FilledButton(
          onPressed: _enableCamera,
          child: const Text('ENABLE CAMERA & MICROPHONE'),
        ),
      ],
    ),
  );

  Widget _cameraView() {
    final value = controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (value?.value.isInitialized == true)
          ColorFiltered(
            colorFilter: ColorFilter.matrix(_filterMatrix()),
            child: CameraPreview(value!),
          )
        else
          const Center(child: CircularProgressIndicator()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: .55),
                Colors.transparent,
                Colors.black87,
              ],
            ),
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: stage == CaptureStage.ready ? context.pop : null,
                    icon: const Icon(Icons.close),
                  ),
                  const Spacer(),
                  if (stage == CaptureStage.ready) ...[
                    IconButton(
                      onPressed: _flip,
                      icon: const Icon(Icons.cameraswitch_outlined),
                    ),
                    IconButton(
                      onPressed:
                          cameras.isNotEmpty &&
                              cameras[cameraIndex].lensDirection ==
                                  CameraLensDirection.back
                          ? () => controller?.setFlashMode(FlashMode.auto)
                          : null,
                      icon: const Icon(Icons.flash_auto),
                    ),
                  ],
                ],
              ),
              if (stage == CaptureStage.ready)
                const Card(
                  color: Colors.black54,
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'One take. Recording cannot be stopped or repeated.',
                    ),
                  ),
                ),
              const Spacer(),
              if (stage == CaptureStage.countdown)
                Text(
                  '$countdown',
                  style: Theme.of(context).textTheme.displayLarge
                      ?.copyWith(fontSize: 120),
                )
              else if (stage == CaptureStage.recording) ...[
                Text(
                  '${math.max(0, 7 - stopwatch.elapsed.inSeconds)}',
                  style: Theme.of(context).textTheme.displayLarge
                      ?.copyWith(fontSize: 96),
                ),
                const SizedBox(height: 18),
                LinearProgressIndicator(value: progress, minHeight: 7),
                const SizedBox(height: 12),
                const Text(
                  '● RECORDING',
                  style: TextStyle(
                    color: SvnlyColors.error,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ] else if (stage == CaptureStage.processing)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Your take is safe. Uploading…'),
                  ],
                ),
              const Spacer(),
              if (stage == CaptureStage.ready) ...[
                SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: freeLooks.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final name = freeLooks[index];
                      return ChoiceChip(
                        selected: look == name,
                        onSelected: (_) => setState(() => look = name),
                        label: Text(name),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  button: true,
                  label: 'Start one-take recording',
                  child: InkWell(
                    onTap: _capture,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                        color: SvnlyColors.lime,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _failure() => SafeArea(
    minimum: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Spacer(),
        const Icon(Icons.warning_amber, size: 64, color: SvnlyColors.warning),
        const SizedBox(height: 18),
        Text(
          'Technical interruption',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 12),
        Text(
          errorMessage ?? 'The camera could not complete this take.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          'A retry is available only after the server verifies that no valid take was published.',
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => context.pop(),
          child: const Text('BACK TO TODAY'),
        ),
      ],
    ),
  );

  Widget _done() => SafeArea(
    minimum: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Spacer(),
        const Icon(Icons.check_circle, size: 78, color: SvnlyColors.success),
        const SizedBox(height: 24),
        Text(
          'DONE ✓',
          style: Theme.of(context).textTheme.displayLarge
              ?.copyWith(fontSize: 52),
        ),
        const SizedBox(height: 12),
        const Text(
          "We're checking your take before it goes live.",
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        FilledButton(
          onPressed: () => context.go('/feed'),
          child: const Text('SEE TODAY’S FEED'),
        ),
      ],
    ),
  );
}
