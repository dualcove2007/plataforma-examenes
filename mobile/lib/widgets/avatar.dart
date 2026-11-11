import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Círculo con la foto del usuario o, si no tiene, su inicial.
///
/// [version] es el `foto_version` que devuelve la API (null = sin foto).
/// [usuarioId] null significa "la foto de quien tiene la sesión abierta".
class AvatarUsuario extends StatefulWidget {
  final ApiService api;
  final String nombre;
  final String? version;
  final int? usuarioId;
  final double tam;
  final Color color;
  final Color colorBorde;
  final double grosorBorde;

  const AvatarUsuario({
    super.key,
    required this.api,
    required this.nombre,
    this.version,
    this.usuarioId,
    this.tam = 46,
    this.color = Paleta.miel,
    this.colorBorde = Paleta.tinta,
    this.grosorBorde = 1.5,
  });

  @override
  State<AvatarUsuario> createState() => _AvatarUsuarioState();
}

class _AvatarUsuarioState extends State<AvatarUsuario> {
  Uint8List? _bytes;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void didUpdateWidget(covariant AvatarUsuario old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version || old.usuarioId != widget.usuarioId) {
      _buscar();
    }
  }

  void _buscar() {
    final v = widget.version;
    if (v == null) {
      _bytes = null;
      return;
    }
    final enCache = widget.api.fotoEnCache(v, usuarioId: widget.usuarioId);
    if (enCache != null) {
      _bytes = enCache;
      return;
    }
    _bytes = null;
    final gen = ++_gen;
    widget.api
        .fotoBytes(v, usuarioId: widget.usuarioId)
        .then((b) {
          if (mounted && gen == _gen) setState(() => _bytes = b);
        })
        .catchError((_) {
          // Sin foto o sin red: se queda la inicial.
        });
  }

  Widget _inicial() {
    final n = widget.nombre.trim();
    return Text(
      n.isEmpty ? '?' : n[0].toUpperCase(),
      style: TextStyle(
        fontSize: widget.tam * 0.42,
        fontWeight: FontWeight.w800,
        color: Paleta.tinta,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    width: widget.tam,
    height: widget.tam,
    alignment: Alignment.center,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: widget.color,
      shape: BoxShape.circle,
      border: Border.all(color: widget.colorBorde, width: widget.grosorBorde),
    ),
    child: _bytes == null
        ? _inicial()
        : Image.memory(
            _bytes!,
            width: widget.tam,
            height: widget.tam,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _inicial(),
          ),
  );
}
