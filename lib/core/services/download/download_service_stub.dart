import 'download_service.dart';

class _StubDownloadService implements DownloadService {
  @override
  Future<GeneratedFileSaveResult> saveFile(GeneratedFileData file) async {
    throw UnsupportedError('File save is not supported on this platform.');
  }

  @override
  Future<bool> openSavedFile({
    required GeneratedFileSaveResult savedFile,
    required String mimeType,
  }) async {
    return false;
  }

  @override
  Future<bool> triggerDownload(GeneratedFileSaveResult savedFile) async {
    return false;
  }
}

DownloadService createDownloadServiceImpl() => _StubDownloadService();
