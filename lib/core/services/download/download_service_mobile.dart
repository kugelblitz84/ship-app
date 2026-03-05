import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'download_service.dart';

class _MobileDownloadService implements DownloadService {
  @override
  Future<GeneratedFileSaveResult> saveFile(GeneratedFileData file) async {
    final directory = await _resolveDownloadBaseDir();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final localFile = File(
      '${directory.path}${Platform.pathSeparator}${file.fileName}',
    );
    await localFile.writeAsBytes(file.bytes, flush: true);

    return GeneratedFileSaveResult(
      fileName: file.fileName,
      locationLabel: directory.path,
      localPath: localFile.path,
    );
  }

  @override
  Future<bool> openSavedFile({
    required GeneratedFileSaveResult savedFile,
    required String mimeType,
  }) async {
    final path = savedFile.localPath;
    if (path == null || path.isEmpty) {
      return false;
    }

    final file = File(path);
    if (!await file.exists()) {
      return false;
    }

    OpenResult result = await OpenFilex.open(path, type: mimeType);

    if (result.type != ResultType.done && Platform.isAndroid) {
      result = await OpenFilex.open(path);
    }

    return result.type == ResultType.done;
  }

  @override
  Future<bool> triggerDownload(GeneratedFileSaveResult savedFile) async {
    return (savedFile.localPath ?? '').isNotEmpty;
  }

  Future<Directory> _resolveDownloadBaseDir() async {
    if (Platform.isAndroid) {
      final androidDownloads = Directory('/storage/emulated/0/Download');
      if (await androidDownloads.exists()) {
        return androidDownloads;
      }

      final altDownloads = Directory('/sdcard/Download');
      if (await altDownloads.exists()) {
        return altDownloads;
      }
    }

    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory != null) {
      return downloadsDirectory;
    }

    final externalDirectory = await getExternalStorageDirectory();
    if (externalDirectory != null) {
      return externalDirectory;
    }

    return getApplicationDocumentsDirectory();
  }
}

DownloadService createDownloadServiceImpl() => _MobileDownloadService();
