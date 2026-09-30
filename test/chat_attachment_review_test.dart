import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tulasisolutionssite/features/chat/chat_screen.dart';

void main() {
  final photoBytes = img.encodePng(img.Image(width: 2, height: 2));
  final files = [
    XFile.fromData(
      photoBytes,
      path: 'photo.png',
      name: 'photo.png',
      mimeType: 'image/png',
    ),
    XFile('report.pdf'),
    XFile('clip.mp4'),
  ];

  testWidgets('reviews multiple files, previews, removes and confirms order', (
    tester,
  ) async {
    final previews = <XFile>[];
    List<XFile>? sent;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                sent = await showDialog<List<XFile>>(
                  context: context,
                  builder: (_) => ChatAttachmentReviewDialog(
                    files: files,
                    onPreview: (file) async => previews.add(file),
                  ),
                );
              },
              child: const Text('Attach'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();
    expect(find.text('Attachments (3)'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(56, 56));
    final thumbnail = tester.widget<Image>(find.byType(Image));
    final resizedImage = thumbnail.image as ResizeImage;
    expect((resizedImage.imageProvider as MemoryImage).bytes, photoBytes);
    expect(sent, isNull);
    await tester.tap(find.byTooltip('Preview photo.png'));
    await tester.pump();
    expect(previews, [files.first]);
    expect(sent, isNull);
    await tester.tap(find.byTooltip('Remove report.pdf'));
    await tester.pump();
    expect(find.text('report.pdf'), findsNothing);
    expect(find.text('Send 2'), findsOneWidget);
    expect(files.length, 3);
    await tester.tap(find.text('Send 2'));
    await tester.pumpAndSettle();
    expect(sent, [files.first, files.last]);
  });

  testWidgets('cancel returns no files and empty selection disables send', (
    tester,
  ) async {
    List<XFile>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showDialog<List<XFile>>(
                  context: context,
                  builder: (_) => ChatAttachmentReviewDialog(
                    files: [files.first],
                    onPreview: (_) async {},
                  ),
                );
              },
              child: const Text('Attach'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Attach'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove photo.png'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selected, isNull);
  });

  testWidgets('long names fit a mobile review dialog', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAttachmentReviewDialog(
            files: [XFile('${'report' * 30}.pdf')],
            onPreview: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Send 1'), findsOneWidget);
  });
}
