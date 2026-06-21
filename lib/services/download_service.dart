import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drama_hub/models/download_model.dart';
import 'package:drama_hub/models/episode_model.dart';

class DownloadService extends GetxService {
  static DownloadService get instance => Get.find<DownloadService>();

  static const String _keyName = 'dramahub_xor_key';
  static const String _metadataKey = 'downloaded_episodes';
  static const int _obfuscateBytes = 1024 * 1024; // 1MB

  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  // ✅ Observable state
  final RxMap<String, ActiveDownload> activeDownloads =
      <String, ActiveDownload>{}.obs;
  final RxList<DownloadedEpisode> completedDownloads =
      <DownloadedEpisode>[].obs;
  final RxInt downloadCount = 0.obs;

  // ✅ NEW — stores real DownloadTask objects so pause/resume/cancel work correctly
  final Map<String, DownloadTask> _activeTasks = {};

  late Uint8List _xorKey;
  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────

  Future<DownloadService> init() async {
    if (_initialized) return this;

    // ✅ Initialize XOR key from secure storage
    await _initXorKey();

    // ✅ Configure background_downloader
    FileDownloader().configure(
      globalConfig: (
        Config.holdingQueue,
        (1, 1, 1), // max 3 concurrent, 2 per host, 1 per group
      ),
    );

    // ✅ Configure notifications
    FileDownloader().configureNotification(
      running: const TaskNotification(
        'Downloading {filename}',
        '{progress}%',
      ),
      complete: const TaskNotification(
        'Download complete',
        '{filename} is ready to watch offline',
      ),
      error: const TaskNotification(
        'Download failed',
        'Tap to retry {filename}',
      ),
      paused: const TaskNotification(
        'Download paused',
        '{filename}',
      ),
      progressBar: true,
    );

    // ✅ Register central update listener
    FileDownloader().updates.listen(_onTaskUpdate);

    // ✅ Resume any background tasks
    await FileDownloader().resumeFromBackground();

    // ✅ NEW — Restore active tasks into maps after resumeFromBackground()
    // This prevents duplicate downloads when user taps download after app restart
    // because isDownloading() will now correctly return true for running tasks
    await _restoreActiveTasksFromBackground();

    // ✅ Load completed downloads from metadata
    await _loadMetadata();

    _initialized = true;
    if (kDebugMode) debugPrint('✅ DownloadService initialized');
    return this;
  }

  // ✅ NEW — restores running background tasks into activeDownloads + _activeTasks
  Future<void> _restoreActiveTasksFromBackground() async {
    try {
      final allTasks = await FileDownloader().allTasks(
        group: 'episodes',
        includeTasksWaitingToRetry: true,
      );

      for (final task in allTasks) {
        if (task is! DownloadTask) continue;
        final episodeId = task.taskId;

        // Skip if already in active map (shouldn't happen but guard anyway)
        if (activeDownloads.containsKey(episodeId)) continue;

        // Parse metadata to restore display info
        try {
          final meta =
              jsonDecode(task.metaData) as Map<String, dynamic>;
          activeDownloads[episodeId] = ActiveDownload(
            episodeId: episodeId,
            episodeTitle: meta['episodeTitle'] ?? '',
            dramaTitle: meta['dramaTitle'] ?? '',
            episodeNumber: meta['episodeNumber'] ?? 0,
          );
          _activeTasks[episodeId] = task;
          if (kDebugMode) {
            debugPrint('✅ Restored background task: $episodeId');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Could not restore task $episodeId: $e');
          }
        }
      }

      downloadCount.value =
          activeDownloads.length + completedDownloads.length;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ restoreActiveTasksFromBackground error: $e');
    }
  }

  Future<void> _initXorKey() async {
    try {
      final existing = await _secureStorage.read(key: _keyName);
      if (existing != null) {
        _xorKey = base64Decode(existing);
        return;
      }
      // Generate new key using OS CSPRNG
      final rng = Random.secure();
      _xorKey = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
      await _secureStorage.write(
        key: _keyName,
        value: base64Encode(_xorKey),
      );
      if (kDebugMode) debugPrint('✅ XOR key generated and stored securely');
    } catch (e) {
      // Fallback key if secure storage fails
      _xorKey = Uint8List.fromList(
          List.generate(32, (i) => (i * 37 + 13) % 256));
      if (kDebugMode) debugPrint('⚠️ Secure storage failed, using fallback key');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PUBLIC API
  // ─────────────────────────────────────────────────────────────────

  /// Check if episode is already downloaded
  bool isDownloaded(String episodeId) {
    return completedDownloads.any((e) => e.episodeId == episodeId);
  }

  /// Check if episode is currently downloading
  bool isDownloading(String episodeId) {
    return activeDownloads.containsKey(episodeId);
  }

  /// Get download progress for episode (0.0 to 1.0)
  double getProgress(String episodeId) {
    return activeDownloads[episodeId]?.progress ?? 0.0;
  }

  /// Get completed download for episode
  DownloadedEpisode? getDownload(String episodeId) {
    try {
      return completedDownloads.firstWhere((e) => e.episodeId == episodeId);
    } catch (_) {
      return null;
    }
  }

  /// Start downloading an episode
  Future<bool> startDownload({
    required EpisodeModel episode,
    required String dramaTitle,
    required String mp4Url,
  }) async {
    // Already downloaded
    if (isDownloaded(episode.id)) return true;
    // ✅ Already downloading — covers restart case now that _restoreActiveTasksFromBackground runs
    if (isDownloading(episode.id)) return true;

    try {
      // Add to active downloads immediately for UI feedback
      // If something is already actively downloading, this one is queued
      final isQueued = activeDownloads.values.any(
        (d) => d.status == DownloadStatus.downloading,
      );
      activeDownloads[episode.id] = ActiveDownload(
        episodeId: episode.id,
        episodeTitle: episode.title,
        dramaTitle: dramaTitle,
        episodeNumber: episode.episodeNumber,
        status: isQueued ? DownloadStatus.queued : DownloadStatus.downloading,
      );
      downloadCount.value = activeDownloads.length + completedDownloads.length;

      // ✅ Create download task
      final task = DownloadTask(
        taskId: episode.id,
        url: mp4Url,
        filename: '${episode.id}.mp4',
        directory: 'downloads',
        baseDirectory: BaseDirectory.applicationSupport,
        group: 'episodes',
        updates: Updates.statusAndProgress,
        allowPause: true,
        priority: 0, // ✅ Android 14+ UIDT — unlimited transfer time
        retries: 5,
        requiresWiFi: false,
        metaData: jsonEncode({
          'episodeId': episode.id,
          'dramaId': episode.dramaId,
          'episodeTitle': episode.title,
          'dramaTitle': dramaTitle,
          'episodeNumber': episode.episodeNumber,
          'thumbnailUrl': episode.thumbnailImage,
        }),
      );

      // ✅ NEW — store real task before enqueue so pause/resume/cancel work
      _activeTasks[episode.id] = task;

      final result = await FileDownloader().enqueue(task);
      if (kDebugMode) debugPrint('✅ Download enqueued: ${episode.id} = $result');
      return result;
    } catch (e) {
      activeDownloads.remove(episode.id);
      _activeTasks.remove(episode.id); // ✅ NEW — clean up on failure
      if (kDebugMode) debugPrint('❌ Download failed to start: $e');
      return false;
    }
  }

  /// Pause a download
  Future<void> pauseDownload(String episodeId) async {
    // ✅ FIX — use stored real task, not dummy DownloadTask(url: '')
    final task = _activeTasks[episodeId];
    if (task == null) {
      if (kDebugMode) debugPrint('⚠️ pauseDownload: no task found for $episodeId');
      return;
    }
    await FileDownloader().pause(task);
    activeDownloads[episodeId]?.status = DownloadStatus.paused;
    activeDownloads.refresh();
  }

  /// Resume a paused download
  Future<void> resumeDownload(String episodeId) async {
    // ✅ FIX — use stored real task, not dummy DownloadTask(url: '')
    final task = _activeTasks[episodeId];
    if (task == null) {
      if (kDebugMode) debugPrint('⚠️ resumeDownload: no task found for $episodeId');
      return;
    }
    await FileDownloader().resume(task);
    activeDownloads[episodeId]?.status = DownloadStatus.downloading;
    activeDownloads.refresh();
  }

  /// Cancel and delete a download
  Future<void> cancelDownload(String episodeId) async {
    // ✅ FIX — use stored real task, not dummy DownloadTask(url: '')
    final task = _activeTasks[episodeId];
    if (task == null) {
      if (kDebugMode) debugPrint('⚠️ cancelDownload: no task found for $episodeId');
      // Still clean up UI state even if task not found
      activeDownloads.remove(episodeId);
      downloadCount.value = activeDownloads.length + completedDownloads.length;
      return;
    }
    await FileDownloader().cancel(task);
    activeDownloads.remove(episodeId);
    _activeTasks.remove(episodeId); // ✅ NEW — clean up stored task
    downloadCount.value = activeDownloads.length + completedDownloads.length;
  }

  /// Delete a completed download
  Future<void> deleteDownload(String episodeId) async {
    final download = getDownload(episodeId);
    if (download == null) return;

    try {
      final file = File(download.filePath);
      if (await file.exists()) await file.delete();

      // ✅ NEW — delete persistent playback cache to prevent storage leak
      try {
        final appSupport = await getApplicationSupportDirectory();
        final cacheFile = File(
            '${appSupport.path}/playback_cache/${episodeId}_play.mp4');
        if (await cacheFile.exists()) await cacheFile.delete();
      } catch (_) {}

      completedDownloads.removeWhere((e) => e.episodeId == episodeId);
      await _saveMetadata();
      downloadCount.value = activeDownloads.length + completedDownloads.length;

      // Remove maturity timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('download_complete_$episodeId');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Delete error: $e');
    }
  }

  /// Get decrypted file path for playback
  /// ✅ FIX — checks persistent cache first for instant playback
  Future<String?> getPlaybackPath(String episodeId) async {
    final download = getDownload(episodeId);
    if (download == null) return null;

    // ✅ INSTANT PATH — reconstruct cache path dynamically (never trust stored absolute path)
    // This is safe across reinstalls, OS upgrades, and path changes
    try {
      final appSupport = await getApplicationSupportDirectory();
      final expectedCachePath =
          '${appSupport.path}/playback_cache/${episodeId}_play.mp4';
      final cachedFile = File(expectedCachePath);
      if (await cachedFile.exists()) {
        if (kDebugMode) {
          debugPrint('✅ Instant playback from cache: $expectedCachePath');
        }
        return expectedCachePath;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ Cache path check failed: $e');
    }

    // Fallback: build from .dramahub (slow — only runs once per episode if cache missed)
    return _buildPlaybackFileFromDramahub(download);
  }

  /// Fallback for legacy downloads or cache-miss — rebuilds from protected .dramahub
  Future<String?> _buildPlaybackFileFromDramahub(DownloadedEpisode download) async {
    final sourceFile = File(download.filePath);
    if (!await sourceFile.exists()) {
      completedDownloads.removeWhere((e) => e.episodeId == download.episodeId);
      await _saveMetadata();
      return null;
    }

    try {
      // ✅ Verify HMAC integrity
      final isValid = await _verifyHmac(sourceFile);
      if (!isValid) {
        if (kDebugMode) {
          debugPrint('⚠️ HMAC verification failed for ${download.episodeId}');
        }
        await deleteDownload(download.episodeId);
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/${download.episodeId}_play.mp4';

      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();

      final sourceLength = await sourceFile.length();
      final contentLength = sourceLength - 32;
      if (contentLength <= 0) return null;

      final deobfuscateLen = contentLength < _obfuscateBytes
          ? contentLength
          : _obfuscateBytes;

      final rafSource = await sourceFile.open(mode: FileMode.read);
      final rafTemp = await tempFile.open(mode: FileMode.write);

      final header = Uint8List(deobfuscateLen.toInt());
      await rafSource.readInto(header);
      for (int i = 0; i < header.length; i++) {
        header[i] = header[i] ^ _xorKey[i % _xorKey.length];
      }
      await rafTemp.writeFrom(header);

      const chunkSize = 256 * 1024;
      int position = deobfuscateLen.toInt();
      while (position < contentLength) {
        final toRead = (position + chunkSize < contentLength)
            ? chunkSize
            : (contentLength - position).toInt();
        final chunk = Uint8List(toRead);
        await rafSource.readInto(chunk);
        await rafTemp.writeFrom(chunk);
        position += toRead;
      }

      await rafSource.close();
      await rafTemp.close();

      if (kDebugMode) debugPrint('✅ Playback file ready (fallback): $tempPath');
      return tempPath;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Playback path error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE — TASK UPDATES
  // ─────────────────────────────────────────────────────────────────

  void _onTaskUpdate(TaskUpdate update) {
    if (update is TaskProgressUpdate) {
      final episodeId = update.task.taskId;

      // ✅ Guard — if task came back from background and not in map yet, restore it
      if (!activeDownloads.containsKey(episodeId)) {
        try {
          final meta =
              jsonDecode(update.task.metaData) as Map<String, dynamic>;
          activeDownloads[episodeId] = ActiveDownload(
            episodeId: episodeId,
            episodeTitle: meta['episodeTitle'] ?? '',
            dramaTitle: meta['dramaTitle'] ?? '',
            episodeNumber: meta['episodeNumber'] ?? 0,
          );
          if (update.task is DownloadTask) {
            _activeTasks[episodeId] = update.task as DownloadTask;
          }
        } catch (_) {}
      }

           if (activeDownloads.containsKey(episodeId)) {
        // ✅ FIX — background_downloader sends negative progress (e.g. -500)
        // when paused. Ignore it so the bar stays frozen and text stays valid.
        if (update.progress >= 0) {
          activeDownloads[episodeId]!.progress = update.progress;

          // ✅ NEW — populate MB fields from update
          // expectedFileSize is -1 if unknown, 0 if not yet determined
          if (update.expectedFileSize > 0) {
            activeDownloads[episodeId]!.totalBytes =
                update.expectedFileSize;
            activeDownloads[episodeId]!.downloadedBytes =
                (update.progress * update.expectedFileSize).round();
          }
        }

        activeDownloads.refresh();
      }
    } else if (update is TaskStatusUpdate) {
      _handleStatusUpdate(update);
    }
  }

  Future<void> _handleStatusUpdate(TaskStatusUpdate update) async {
    final episodeId = update.task.taskId;

    switch (update.status) {
      case TaskStatus.complete:
        await _onDownloadComplete(update.task);
        _promoteNextQueued();
        break;

      case TaskStatus.failed:
        activeDownloads[episodeId]?.status = DownloadStatus.failed;
        activeDownloads.refresh();
        if (kDebugMode) debugPrint('❌ Download failed: $episodeId');
        break;

      case TaskStatus.paused:
        activeDownloads[episodeId]?.status = DownloadStatus.paused;
        activeDownloads.refresh();
        break;

      case TaskStatus.canceled:
        activeDownloads.remove(episodeId);
        _activeTasks.remove(episodeId); // ✅ NEW — clean up stored task
        downloadCount.value =
            activeDownloads.length + completedDownloads.length;
        _promoteNextQueued();
        break;

      default:
        break;
    }
  }

  void _promoteNextQueued() {
    final next = activeDownloads.values
        .where((d) => d.status == DownloadStatus.queued)
        .firstOrNull;
    if (next != null) {
      activeDownloads[next.episodeId]!.status = DownloadStatus.downloading;
      activeDownloads.refresh();
    }
  }

  Future<void> _onDownloadComplete(Task task) async {
    final episodeId = task.taskId;
    if (kDebugMode) debugPrint('✅ Download complete: $episodeId');

    try {
      // Get file path
      final filePath = await task.filePath();
      final file = File(filePath);

      if (!await file.exists()) {
        if (kDebugMode) debugPrint('❌ Downloaded file not found: $filePath');
        return;
      }

      // ✅ Work on .tmp throughout the pipeline — .dramahub only appears on
      // disk after every step succeeds (atomic commit pattern)
      final dramahubPath = filePath.replaceAll('.mp4', '.dramahub');
      final tmpPath = '$dramahubPath.tmp';

      final tmpFile = await file.rename(tmpPath);

      // ✅ XOR obfuscate first 1MB
      await _obfuscateFile(tmpFile);

      // ✅ Append HMAC
      await _appendHmac(tmpFile);

      // ✅ Prepare instant-playback cache from .tmp (before final rename)
      String? playbackCachePath;
      try {
        playbackCachePath = await _preparePlaybackFile(tmpFile, episodeId);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Playback cache prep failed: $e');
      }

      // ✅ Atomic commit — only now does a valid .dramahub file exist on disk
      final renamedFile = await tmpFile.rename(dramahubPath);

      // ✅ Parse metadata
      final meta = jsonDecode(task.metaData) as Map<String, dynamic>;
      final stat = await renamedFile.stat();

      // ✅ Save completion timestamp for maturity check
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'download_complete_$episodeId',
        DateTime.now().millisecondsSinceEpoch,
      );

      // ✅ Add to completed list
      final downloaded = DownloadedEpisode(
        episodeId: episodeId,
        dramaId: meta['dramaId'] ?? '',
        episodeTitle: meta['episodeTitle'] ?? '',
        dramaTitle: meta['dramaTitle'] ?? '',
        episodeNumber: meta['episodeNumber'] ?? 0,
        thumbnailUrl: meta['thumbnailUrl'] ?? '',
        filePath: renamedFile.path,
        fileSizeBytes: stat.size,
        downloadedAt: DateTime.now(),
        isComplete: true,
        playbackPath: playbackCachePath,
      );

      completedDownloads.add(downloaded);
      activeDownloads.remove(episodeId);
      _activeTasks.remove(episodeId); // ✅ NEW — clean up stored task
      downloadCount.value = activeDownloads.length + completedDownloads.length;

      await _saveMetadata();
      if (kDebugMode) debugPrint('✅ Episode saved as .dramahub: $episodeId');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Post-download processing error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE — PLAYBACK CACHE PREPARATION
  // ─────────────────────────────────────────────────────────────────

  /// Builds playback-ready .mp4 cache immediately after download.
  /// Runs once in background — user never waits on tap.
  /// If disk is full, OS throws FileSystemException → caught → returns null
  /// → app safely falls back to slow on-demand path. No crash.
  Future<String?> _preparePlaybackFile(File sourceFile, String episodeId) async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appSupport.path}/playback_cache');
      await cacheDir.create(recursive: true);

      final playbackPath = '${cacheDir.path}/${episodeId}_play.mp4';
      final playbackFile = File(playbackPath);
      if (await playbackFile.exists()) await playbackFile.delete();

      final sourceLength = await sourceFile.length();
      final contentLength = sourceLength - 32;
      if (contentLength <= 0) return null;

      final deobfuscateLen = contentLength < _obfuscateBytes
          ? contentLength
          : _obfuscateBytes;

      final rafSource = await sourceFile.open(mode: FileMode.read);
      final rafDest = await playbackFile.open(mode: FileMode.write);

      // STEP 1 — XOR first 1 MB and write to cache
      final header = Uint8List(deobfuscateLen.toInt());
      await rafSource.readInto(header);
      for (int i = 0; i < header.length; i++) {
        header[i] = header[i] ^ _xorKey[i % _xorKey.length];
      }
      await rafDest.writeFrom(header);

      // STEP 2 — Copy remaining bytes in 256 KB chunks
      const chunkSize = 256 * 1024;
      int position = deobfuscateLen.toInt();
      while (position < contentLength) {
        final toRead = (position + chunkSize < contentLength)
            ? chunkSize
            : (contentLength - position).toInt();
        final chunk = Uint8List(toRead);
        await rafSource.readInto(chunk);
        await rafDest.writeFrom(chunk);
        position += toRead;
      }

      await rafSource.close();
      await rafDest.close();

      if (kDebugMode) debugPrint('✅ Playback cache prepared: $playbackPath');
      return playbackPath;
    } catch (e) {
      // Includes FileSystemException when disk is full — safe fallback
      if (kDebugMode) debugPrint('❌ Prepare playback file error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE — SECURITY (completely untouched)
  // ─────────────────────────────────────────────────────────────────

  Future<void> _obfuscateFile(File file) async {
    final fileLength = await file.length();
    if (fileLength == 0) return;

    final obfuscateLen =
        (fileLength < _obfuscateBytes ? fileLength : _obfuscateBytes).toInt();

    // Read only the first obfuscateLen bytes (max 1 MB)
    final rafRead = await file.open(mode: FileMode.read);
    final header = Uint8List(obfuscateLen);
    await rafRead.readInto(header);
    await rafRead.close();

    // XOR in place (memory: max 1 MB)
    for (int i = 0; i < header.length; i++) {
      header[i] = header[i] ^ _xorKey[i % _xorKey.length];
    }

    // Write XOR'd bytes back to position 0 only (rest of file untouched)
    final rafWrite = await file.open(mode: FileMode.writeOnlyAppend);
    await rafWrite.setPosition(0);
    await rafWrite.writeFrom(header);
    await rafWrite.close();

    if (kDebugMode) debugPrint('✅ File obfuscated: ${file.path}');
  }

  Future<void> _appendHmac(File file) async {
    // Compute HMAC over full content in 256 KB chunks — mirrors _verifyHmac() exactly
    const chunkSize = 256 * 1024;
    final fileLength = await file.length();
    final digestSink = _DigestCollector();
    final inputSink = Hmac(sha256, _xorKey).startChunkedConversion(digestSink);

    final raf = await file.open(mode: FileMode.read);
    int position = 0;
    while (position < fileLength) {
      final toRead = (position + chunkSize < fileLength)
          ? chunkSize
          : (fileLength - position).toInt();
      final chunk = Uint8List(toRead);
      await raf.readInto(chunk);
      inputSink.add(chunk);
      position += toRead;
    }
    await raf.close();
    inputSink.close();

    // Append only the 32-byte digest — never loads full file into memory
    final rafAppend = await file.open(mode: FileMode.writeOnlyAppend);
    await rafAppend.writeFrom(Uint8List.fromList(digestSink.digest.bytes));
    await rafAppend.close();

    if (kDebugMode) debugPrint('✅ HMAC appended');
  }

  Future<bool> _verifyHmac(File file) async {
    try {
      final fileLength = await file.length();
      if (fileLength < 32) return false;

      // ✅ Read stored HMAC — last 32 bytes only (no full file load)
      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(fileLength - 32);
      final storedHmac = Uint8List(32);
      await raf.readInto(storedHmac);
      await raf.close();

      // ✅ Compute HMAC over content in 256KB chunks — never full file in memory
      const chunkSize = 256 * 1024;
      final contentLength = fileLength - 32;
      final digestSink = _DigestCollector();
      final inputSink =
          Hmac(sha256, _xorKey).startChunkedConversion(digestSink);

      final rafVerify = await file.open(mode: FileMode.read);
      int position = 0;
      while (position < contentLength) {
        final toRead = (position + chunkSize < contentLength)
            ? chunkSize
            : (contentLength - position).toInt();
        final chunk = Uint8List(toRead);
        await rafVerify.readInto(chunk);
        inputSink.add(chunk);
        position += toRead;
      }
      await rafVerify.close();
      inputSink.close();

      return listEquals(digestSink.digest.bytes, storedHmac);
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // PRIVATE — METADATA PERSISTENCE (completely untouched)
  // ─────────────────────────────────────────────────────────────────

  Future<void> _saveMetadata() async {
    final prefs = await SharedPreferences.getInstance();
    final list = completedDownloads.map((e) => e.toJson()).toList();
    await prefs.setString(_metadataKey, jsonEncode(list));
  }

  Future<void> _loadMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_metadataKey);
      if (raw == null) return;

      final list = jsonDecode(raw) as List;
      final episodes = list
          .map((e) => DownloadedEpisode.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();

      // ✅ Verify files still exist
      final valid = <DownloadedEpisode>[];
      for (final ep in episodes) {
        if (await File(ep.filePath).exists()) {
          valid.add(ep);
        }
      }

      completedDownloads.assignAll(valid);
      downloadCount.value = completedDownloads.length;
      if (kDebugMode) {
        debugPrint('✅ Loaded ${valid.length} downloads from metadata');
      }

      // ✅ Sweep for orphaned .tmp files left by a killed pipeline
      try {
        final appSupport = await getApplicationSupportDirectory();
        final downloadsDir = Directory('${appSupport.path}/downloads');
        if (await downloadsDir.exists()) {
          final orphans = downloadsDir
              .listSync()
              .whereType<File>()
              .where((f) => f.path.endsWith('.dramahub.tmp'));
          for (final orphan in orphans) {
            await orphan.delete();
            if (kDebugMode) {
              debugPrint('🧹 Deleted orphaned tmp: ${orphan.path}');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Orphan sweep error: $e');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Metadata load error: $e');
    }
  }

  /// Clean up temp playback files
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = Directory(tempDir.path)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('_play.mp4'));
      for (final f in files) {
        await f.delete();
      }
    } catch (_) {}
  }

  /// Clean up temp fallback file for ONE specific episode only.
  /// Use this in dispose() to avoid touching any other episode's temp file.
  Future<void> cleanupTempFile(String episodeId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${episodeId}_play.mp4');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

// ✅ Helper — collects chunked HMAC digest result
class _DigestCollector implements Sink<Digest> {
  late Digest digest;

  @override
  void add(Digest data) {
    digest = data;
  }

  @override
  void close() {}
}