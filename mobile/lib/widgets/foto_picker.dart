import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Imagen ya elegida y lista para subir.
class FotoElegida {
  final Uint8List bytes;
  final String nombre;
  const FotoElegida(this.bytes, this.nombre);
}

enum AccionFoto { galeria, camara, quitar }

/// Hoja inferior con las opciones para la foto de perfil.
Future<AccionFoto?> menuFoto(BuildContext context, {required bool tieneFoto}) =>
    showModalBottomSheet<AccionFoto>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, AccionFoto.galeria),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(ctx, AccionFoto.camara),
            ),
            if (tieneFoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.pop(ctx, AccionFoto.quitar),
              ),
          ],
        ),
      ),
    );

/// Abre la galería o la cámara y devuelve la imagen (null si cancela).
/// Lanza una excepción con un mensaje claro si el archivo no sirve.
Future<FotoElegida?> seleccionarFoto(AccionFoto accion) async {
  final XFile? x;
  try {
    x = await ImagePicker().pickImage(
      source: accion == AccionFoto.camara
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
  } catch (_) {
    throw Exception('No se pudo abrir la cámara o la galería.');
  }
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  // El servidor solo acepta PNG o JPG; se decide por el contenido, no por el nombre.
  final esPng =
      bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E;
  final esJpg = bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8;
  if (!esPng && !esJpg) throw Exception('Usa una imagen JPG o PNG.');
  return FotoElegida(bytes, esPng ? 'foto.png' : 'foto.jpg');
}
