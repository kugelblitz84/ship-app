import 'dart:html' as html;

import 'download_service.dart';

class _WebDownloadService implements DownloadService {
  @override
  Future<GeneratedFileSaveResult> saveFile(GeneratedFileData file) async {
    final blob = html.Blob(<Object>[file.bytes], file.mimeType);
    final objectUrl = html.Url.createObjectUrlFromBlob(blob);

    return GeneratedFileSaveResult(
      fileName: file.fileName,
      locationLabel: 'Browser download ready',
      objectUrl: objectUrl,
      supportsExplicitDownload: true,
    );
  }

  @override
  Future<bool> openSavedFile({
    required GeneratedFileSaveResult savedFile,
    required String mimeType,
  }) async {
    final objectUrl = savedFile.objectUrl;
    if (objectUrl == null || objectUrl.isEmpty) {
      return false;
    }

    html.window.open(objectUrl, '_blank');
    return true;
  }

  @override
  Future<bool> triggerDownload(GeneratedFileSaveResult savedFile) async {
    final objectUrl = savedFile.objectUrl;
    if (objectUrl == null || objectUrl.isEmpty) {
      return false;
    }

    final anchor = html.AnchorElement(href: objectUrl)
      ..download = savedFile.fileName
      ..style.display = 'none';

    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();

    return true;
  }
}

DownloadService createDownloadServiceImpl() => _WebDownloadService();
