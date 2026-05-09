import 'dart:io';

import '_workspace_cli.dart';

Future<void> main(List<String> args) async {
  enterWorkspaceRoot();

  if (args.isEmpty) {
    stderr.writeln(_usage);
    exit(64);
  }

  switch (args.first) {
    case 'app:clean':
      await _appClean();
      return;
    case 'app:rebuild':
      await _appRebuild(args.sublist(1));
      return;
    case 'native:prepare':
      await _nativePrepare(args.sublist(1));
      return;
    case 'run:prepare':
      await _runPrepare();
      return;
    case 'release:prepare':
      await _releasePrepare(args.sublist(1));
      return;
    case 'help':
    case '--help':
    case '-h':
      stdout.writeln(_usage);
      return;
    default:
      stderr.writeln('未知项目任务: ${args.first}');
      stderr.writeln(_usage);
      exit(64);
  }
}

Future<void> _appClean() async {
  await runFlutterOrExit(title: '执行 flutter clean', arguments: const ['clean']);
  resetPubGetStamp();
}

Future<void> _appRebuild(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(
      '用法: dart tool/project_tasks.dart app:rebuild <flutter build args...>',
    );
    exit(64);
  }

  await _appClean();
  await runOrExit(
    title: '执行 flutter build ${args.join(' ')}',
    executable: Platform.resolvedExecutable,
    arguments: ['tool/flutterw.dart', 'build', ...args],
  );
}

Future<void> _runPrepare() async {
  await _runProjectPrep('app');
}

Future<void> _nativePrepare(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      '用法: dart tool/project_tasks.dart native:prepare <android|linux> <--debug|--profile|--release> [--target-platform=<android-target>]',
    );
    exit(64);
  }

  final platform = args[0];
  final buildMode = args[1];
  final extraArgs = args.sublist(2);

  if (!const {'android', 'linux'}.contains(platform)) {
    stderr.writeln('不支持的原生平台: $platform');
    exit(64);
  }

  if (!const {'--debug', '--profile', '--release'}.contains(buildMode)) {
    stderr.writeln('不支持的构建模式: $buildMode');
    exit(64);
  }

  final targetPlatform = _extractTargetPlatform(extraArgs);
  if (platform == 'android') {
    _validateAndroidTargetPlatform(targetPlatform);
  } else if (targetPlatform != null) {
    stderr.writeln('linux 原生预处理不支持 --target-platform');
    exit(64);
  }

  final targetDescription = targetPlatform == null ? '' : ' ($targetPlatform)';
  stdout.writeln('==> $platform $buildMode$targetDescription 无需额外原生预处理');
}

Future<void> _releasePrepare(List<String> args) async {
  final strictAnalyze = args.contains('--strict-analyze');
  final skipAnalyze = args.contains('--skip-analyze');
  final skipTest = args.contains('--skip-test');

  await _runProjectPrep('app');

  if (!skipAnalyze) {
    await runFlutterOrExit(
      title: strictAnalyze ? '执行 flutter analyze' : '执行 flutter analyze（非严格模式）',
      arguments: [
        'analyze',
        if (!strictAnalyze) ...const [
          '--no-fatal-infos',
          '--no-fatal-warnings',
        ],
      ],
    );
  }

  if (!skipTest) {
    await runFlutterOrExit(title: '执行 flutter test', arguments: const ['test']);
  }
}

Future<void> _runProjectPrep(String command) {
  return runOrExit(
    title: '执行项目预处理 $command',
    executable: Platform.resolvedExecutable,
    arguments: ['tool/project_prep.dart', command],
  );
}

String? _extractTargetPlatform(List<String> args) {
  String? targetPlatform;
  for (var index = 0; index < args.length; index++) {
    final value = args[index];
    if (value == '--target-platform') {
      if (index + 1 >= args.length) {
        stderr.writeln('--target-platform 缺少取值');
        exit(64);
      }
      targetPlatform = args[++index];
      continue;
    }
    if (value.startsWith('--target-platform=')) {
      targetPlatform = value.substring('--target-platform='.length);
      continue;
    }
    stderr.writeln('未知 native:prepare 参数: $value');
    exit(64);
  }
  return targetPlatform;
}

void _validateAndroidTargetPlatform(String? targetPlatform) {
  if (targetPlatform == null || targetPlatform.isEmpty) {
    return;
  }
  final platforms = targetPlatform.split(',').map((value) => value.trim());
  const supportedPlatforms = {'android-arm', 'android-arm64', 'android-x64'};
  for (final platform in platforms) {
    if (!supportedPlatforms.contains(platform)) {
      stderr.writeln('不支持的 Android target platform: $platform');
      exit(64);
    }
  }
}

const _usage = '''
用法:
  dart tool/project_tasks.dart app:clean
  dart tool/project_tasks.dart app:rebuild <flutter build args...>
  dart tool/project_tasks.dart native:prepare <android|linux> <--debug|--profile|--release> [--target-platform=<android-target>]
  dart tool/project_tasks.dart run:prepare
  dart tool/project_tasks.dart release:prepare [--skip-analyze] [--skip-test] [--strict-analyze]
''';
