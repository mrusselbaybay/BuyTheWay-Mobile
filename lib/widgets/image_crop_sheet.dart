import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Pan/zoom avatar cropper — the Flutter counterpart of the web app's
/// resources/js/buyer/components/AvatarCropper.vue, shown between "pick a
/// photo" and "actually upload it".
///
/// Same behaviour as the web version: the picked image is fitted to
/// *cover* a square frame, the user drags to reposition and pinches (or
/// drags the slider) to zoom, and exactly what's visible in the frame is
/// exported as a square image at [_outputSize]px — re-rendered from the
/// full-resolution decoded bitmap, not from the downscaled preview, so the
/// upload stays sharp. No cropping package: just gesture math and a
/// [ui.PictureRecorder], matching how the web side avoids a dependency too.

const double _viewport = 280;
const double _outputSize = 480;
const double _qrOutputSize = 720;
const double _maxZoom = 4;

/// Opens the system picker (camera or gallery), then the cropper.
/// Resolves to the cropped PNG bytes, or null if the user backed out of
/// either step.
Future<Uint8List?> pickAndCropImage(BuildContext context,
    {bool qr = false}) async {
  final source = await _askImageSource(context);
  if (source == null) return null;

  final picked = await ImagePicker().pickImage(
    source: source,
    // Generous cap: the cropper re-encodes to a fixed 480px square
    // anyway, so this only bounds decode cost/memory on huge camera
    // originals — it isn't the upload size.
    maxWidth: 2400,
    maxHeight: 2400,
    imageQuality: 92,
  );
  if (picked == null) return null;

  final bytes = await picked.readAsBytes();
  if (!context.mounted) return null;

  return showImageCropper(context, bytes, qr: qr);
}

/// Shows the cropper for already-loaded image [bytes].
///
/// With [qr] the frame is a square box (not a circle) that starts with the
/// whole picture visible and can be zoomed out, and the export is padded
/// with white — a QR code must never be cut off.
Future<Uint8List?> showImageCropper(BuildContext context, Uint8List bytes,
    {bool qr = false}) {
  return showDialog<Uint8List>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (_) => _ImageCropDialog(bytes: bytes, qr: qr),
  );
}

Future<ImageSource?> _askImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: const Text('Take a photo',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from gallery',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _ImageCropDialog extends StatefulWidget {
  const _ImageCropDialog({required this.bytes, this.qr = false});

  final Uint8List bytes;
  final bool qr;

  @override
  State<_ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<_ImageCropDialog> {
  ui.Image? _image;
  String? _decodeError;
  bool _exporting = false;

  /// Scale at which the image exactly covers the square frame at zoom 1.
  double _baseScale = 1;
  double _zoom = 1;
  Offset _offset = Offset.zero;

  /// Zoom when the current pinch began. [ScaleUpdateDetails.scale] is
  /// cumulative across the gesture, so it multiplies this rather than the
  /// live value; the pan delta is incremental and accumulates instead.
  double _zoomAtGestureStart = 1;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        final fit = widget.qr ? math.min<double> : math.max<double>;
        _baseScale = fit(
          _viewport / frame.image.width,
          _viewport / frame.image.height,
        );
        _zoom = 1;
        _offset = Offset.zero;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
          () => _decodeError = "That file couldn't be opened as an image.");
    }
  }

  double get _displayWidth => (_image?.width ?? 0) * _baseScale * _zoom;
  double get _displayHeight => (_image?.height ?? 0) * _baseScale * _zoom;

  /// Keeps the frame full of photo — the image can never be dragged or
  /// zoomed out far enough to expose empty space inside the circle.
  Offset _clamp(Offset offset) {
    final maxX = math.max((_displayWidth - _viewport) / 2, 0.0);
    final maxY = math.max((_displayHeight - _viewport) / 2, 0.0);
    return Offset(
      offset.dx.clamp(-maxX, maxX),
      offset.dy.clamp(-maxY, maxY),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtGestureStart = _zoom;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _zoom = (_zoomAtGestureStart * details.scale)
          .clamp(widget.qr ? 0.5 : 1.0, _maxZoom);
      _offset = _clamp(_offset + details.focalPointDelta);
    });
  }

  void _onZoomSliderChanged(double value) {
    setState(() {
      _zoom = value;
      _offset = _clamp(_offset);
    });
  }

  /// Renders the visible square straight from the decoded bitmap.
  Future<void> _save() async {
    final image = _image;
    if (image == null || _exporting) return;

    setState(() => _exporting = true);
    try {
      final scaleFactor = _baseScale * _zoom;
      final sourceSize = _viewport / scaleFactor;
      final sourceX =
          (_displayWidth / 2 - _viewport / 2 - _offset.dx) / scaleFactor;
      final sourceY =
          (_displayHeight / 2 - _viewport / 2 - _offset.dy) / scaleFactor;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (widget.qr) {
        // Place the whole picture where it sits in the frame, on white.
        const out = _qrOutputSize / _viewport;
        canvas.drawRect(const Rect.fromLTWH(0, 0, _qrOutputSize, _qrOutputSize),
            Paint()..color = Colors.white);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(
              (_viewport / 2 - _displayWidth / 2 + _offset.dx) * out,
              (_viewport / 2 - _displayHeight / 2 + _offset.dy) * out,
              _displayWidth * out,
              _displayHeight * out),
          Paint()..filterQuality = FilterQuality.high,
        );
      } else {
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(sourceX, sourceY, sourceSize, sourceSize),
          const Rect.fromLTWH(0, 0, _outputSize, _outputSize),
          Paint()..filterQuality = FilterQuality.high,
        );
      }
      final picture = recorder.endRecording();
      final side = (widget.qr ? _qrOutputSize : _outputSize).round();
      final cropped = await picture.toImage(side, side);
      picture.dispose();

      final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
      cropped.dispose();

      if (!mounted) return;
      if (data == null) {
        setState(() {
          _exporting = false;
          _decodeError = "That photo couldn't be processed. Try another one.";
        });
        return;
      }
      Navigator.of(context).pop(data.buffer.asUint8List());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _decodeError = "That photo couldn't be processed. Try another one.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.qr ? 'Crop your QR code' : 'Adjust your photo',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.qr
                  ? 'Keep the whole QR code inside the square. Drag to move, pinch or use the slider to zoom.'
                  : 'Drag to reposition, pinch or use the slider to zoom.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            _viewportBox(),
            const SizedBox(height: 16),
            _zoomRow(theme),
            if (_decodeError != null) ...[
              const SizedBox(height: 10),
              Text(
                _decodeError!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _exporting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _image == null || _exporting ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: _exporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(widget.qr ? 'Use this QR' : 'Use photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewportBox() {
    final image = _image;
    return SizedBox(
      width: _viewport,
      height: _viewport,
      child: _frameClip(
        child: Container(
          color: widget.qr ? Colors.white : const Color(0xFF0F172A),
          child: image == null
              ? const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white70),
                  ),
                )
              : GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  child: Stack(
                    children: [
                      Positioned(
                        left: _viewport / 2 - _displayWidth / 2 + _offset.dx,
                        top: _viewport / 2 - _displayHeight / 2 + _offset.dy,
                        width: _displayWidth,
                        height: _displayHeight,
                        child: RawImage(image: image, fit: BoxFit.fill),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _frameClip({required Widget child}) => widget.qr
      ? DecoratedBox(
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF176450), width: 2),
              borderRadius: BorderRadius.circular(10)),
          child:
              ClipRRect(borderRadius: BorderRadius.circular(8), child: child))
      : ClipOval(child: child);

  Widget _zoomRow(ThemeData theme) {
    return Row(
      children: [
        Icon(Icons.image_outlined, size: 15, color: Colors.grey.shade500),
        Expanded(
          child: Slider(
            value: _zoom,
            min: widget.qr ? 0.5 : 1,
            max: _maxZoom,
            onChanged:
                _image == null || _exporting ? null : _onZoomSliderChanged,
          ),
        ),
        Icon(Icons.image_rounded, size: 21, color: Colors.grey.shade500),
      ],
    );
  }
}
