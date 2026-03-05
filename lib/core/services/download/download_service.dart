import 'dart:typed_data';

import 'download_service_stub.dart'
    if (dart.library.io) 'download_service_mobile.dart'
    if (dart.library.html) 'download_service_web.dart';

class GeneratedFileData {
  const GeneratedFileData({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

class GeneratedFileSaveResult {
  const GeneratedFileSaveResult({
    required this.fileName,
    required this.locationLabel,
    this.localPath,
    this.objectUrl,
    this.supportsExplicitDownload = false,
  });

  final String fileName;
  final String locationLabel;
  final String? localPath;
  final String? objectUrl;
  final bool supportsExplicitDownload;
}

abstract class DownloadService {
  Future<GeneratedFileSaveResult> saveFile(GeneratedFileData file);

  Future<bool> openSavedFile({
    required GeneratedFileSaveResult savedFile,
    required String mimeType,
  });

  Future<bool> triggerDownload(GeneratedFileSaveResult savedFile);
}

DownloadService createDownloadService() => createDownloadServiceImpl();
