import 'dart:io';

Future<void> main() async {
  final result = await Process.start(
    'flutter',
    ['analyze'],
    workingDirectory: Directory.current.path,
    runInShell: Platform.isWindows,
  );

  await stdout.addStream(result.stdout);
  await stderr.addStream(result.stderr);
  exit(await result.exitCode);
}