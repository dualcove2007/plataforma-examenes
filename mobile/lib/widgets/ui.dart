import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

// ───────────────────────── Utilidades ─────────────────────────

String mensajeError(Object e) => e.toString().replaceFirst('Exception: ', '');

const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// "2026-11-02T14:05:00Z" → "2 nov 2026, 09:05" (hora local).
String fechaCorta(String? iso) {
  final f = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (f == null) return '—';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${f.day} ${_meses[f.month - 1]} ${f.year}, ${dos(f.hour)}:${dos(f.minute)}';
}

void mostrarAviso(BuildContext context, String texto, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_rounded : Icons.check_circle_rounded,
              color: error ? Paleta.coral : Paleta.miel,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
      ),
    );
}

Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Confirmar',
  IconData icono = Icons.help_rounded,
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      icon: IconBadge(
        icono,
        fondo: peligro ? Paleta.coralSuave : Paleta.verdeSuave,
        tam: 56,
      ),
      title: Text(titulo, textAlign: TextAlign.center),
      content: Text(mensaje, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(120, 44),
            backgroundColor: peligro ? Paleta.coral : Paleta.verde,
            foregroundColor: peligro ? Paleta.tinta : Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return r == true;
}

// ───────────────────────── Piezas básicas ─────────────────────────

/// Cuadrito redondeado de color con un ícono dentro.
class IconBadge extends StatelessWidget {
  final IconData icono;
  final Color fondo;
  final Color color;
  final double tam;
  const IconBadge(
    this.icono, {
    super.key,
    this.fondo = Paleta.verdeSuave,
    this.color = Paleta.tinta,
    this.tam = 44,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: tam,
    height: tam,
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(tam * 0.32),
    ),
    child: Icon(icono, color: color, size: tam * 0.52),
  );
}

/// Tarjeta plana: fondo sólido, borde fino y sin sombra.
class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Paleta.borde, width: 1.5),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// Pastilla pequeña con ícono opcional ("Docente", "Inactivo"...).
class Etiqueta extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final Color fondo;
  const Etiqueta(
    this.texto, {
    super.key,
    this.icono,
    this.fondo = Paleta.verdeSuave,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icono != null) ...[
          Icon(icono, size: 14, color: Paleta.tinta),
          const SizedBox(width: 4),
        ],
        Text(
          texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Paleta.tinta,
          ),
        ),
      ],
    ),
  );
}

class _Circulo extends StatelessWidget {
  final double d;
  final Color color;
  const _Circulo(this.d, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: d,
    height: d,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Cabecera de color sólido (sin degradado) con círculos decorativos.
class CabeceraSeccion extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Seccion seccion;
  final List<Widget> acciones;
  const CabeceraSeccion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seccion,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final claro = seccion.texto == Colors.white;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: claro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: seccion.fondo,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -34,
              child: _Circulo(130, seccion.deco),
            ),
            Positioned(
              right: 70,
              bottom: -46,
              child: _Circulo(86, seccion.deco),
            ),
            Positioned(
              left: -24,
              bottom: -34,
              child: _Circulo(74, seccion.deco),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 10, 24),
                child: Row(
                  children: [
                    IconBadge(icono, fondo: Colors.white, tam: 52),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo,
                            style: t.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: seccion.texto,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            style: t.bodyMedium?.copyWith(
                              color: seccion.texto.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...acciones,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  final String titulo;
  final String mensaje;
  const EstadoVacio({super.key, required this.titulo, required this.mensaje});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/images/vacio.svg', width: 190),
          const SizedBox(height: 16),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Paleta.tintaSuave),
          ),
        ],
      ),
    ),
  );
}

class EstadoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const EstadoError({
    super.key,
    required this.mensaje,
    required this.onReintentar,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconBadge(
            Icons.cloud_off_rounded,
            fondo: Paleta.coralSuave,
            tam: 64,
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Paleta.tintaSuave),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onReintentar,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Búsqueda y filtros ─────────────────────────

/// Campo de búsqueda que avisa 400 ms después de que dejas de escribir.
class CampoBusqueda extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onCambio;
  const CampoBusqueda({super.key, required this.hint, required this.onCambio});

  @override
  State<CampoBusqueda> createState() => _CampoBusquedaState();
}

class _CampoBusquedaState extends State<CampoBusqueda> {
  final _c = TextEditingController();
  Timer? _t;

  void _cambio(String v) {
    setState(() {});
    _t?.cancel();
    _t = Timer(
      const Duration(milliseconds: 400),
      () => widget.onCambio(v.trim()),
    );
  }

  void _limpiar() {
    _c.clear();
    _t?.cancel();
    setState(() {});
    widget.onCambio('');
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    onChanged: _cambio,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: widget.hint,
      prefixIcon: const Icon(Icons.search_rounded),
      suffixIcon: _c.text.isEmpty
          ? null
          : IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _limpiar,
            ),
    ),
  );
}

class OpcionFiltro<T> {
  final String texto;
  final T valor;
  final IconData? icono;
  const OpcionFiltro(this.texto, this.valor, [this.icono]);
}

/// Fila horizontal de chips para filtrar (una opción activa a la vez).
class FilaFiltros<T> extends StatelessWidget {
  final List<OpcionFiltro<T>> opciones;
  final T valor;
  final ValueChanged<T> onCambio;
  const FilaFiltros({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 42,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: opciones.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final o = opciones[i];
        return ChoiceChip(
          avatar: o.icono == null ? null : Icon(o.icono, size: 18),
          label: Text(o.texto),
          selected: o.valor == valor,
          onSelected: (_) => onCambio(o.valor),
        );
      },
    ),
  );
}

// ───────────────────────── Lista paginada ─────────────────────────

/// Lista con scroll infinito, pull-to-refresh y manejo de carga/vacío/error.
/// Si cambia [filtro] se recarga desde la página 1.
class ListaPaginada extends StatefulWidget {
  final Future<Pagina> Function(int pagina) cargar;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;
  final Widget vacio;
  final Object? filtro;
  final EdgeInsets padding;
  const ListaPaginada({
    super.key,
    required this.cargar,
    required this.itemBuilder,
    required this.vacio,
    this.filtro,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 96),
  });

  @override
  State<ListaPaginada> createState() => ListaPaginadaState();
}

class ListaPaginadaState extends State<ListaPaginada> {
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  int _pagina = 0;
  int _gen = 0; // descarta respuestas de cargas anteriores
  bool _hayMas = true;
  bool _cargando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _siguiente();
    });
    _siguiente();
  }

  @override
  void didUpdateWidget(covariant ListaPaginada old) {
    super.didUpdateWidget(old);
    if (old.filtro != widget.filtro) recargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> recargar() {
    _gen++;
    _items.clear();
    _pagina = 0;
    _hayMas = true;
    _cargando = false;
    _error = null;
    if (mounted) setState(() {});
    return _siguiente();
  }

  Future<void> _siguiente() async {
    if (_cargando || !_hayMas) return;
    final gen = _gen;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final p = await widget.cargar(_pagina + 1);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items.addAll(p.items);
        _pagina++;
        _hayMas = p.hayMas;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _error = mensajeError(e));
    } finally {
      if (mounted && gen == _gen) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      if (_cargando) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return EstadoError(mensaje: _error!, onReintentar: _siguiente);
      }
      return RefreshIndicator(
        onRefresh: recargar,
        child: LayoutBuilder(
          builder: (_, c) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(height: c.maxHeight, child: widget.vacio),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i < _items.length) return widget.itemBuilder(context, _items[i]);
          if (_error != null) {
            return Center(
              child: TextButton.icon(
                onPressed: _siguiente,
                icon: const Icon(Icons.refresh_rounded),
                label: Text('$_error  ·  Reintentar'),
              ),
            );
          }
          return _hayMas
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox(height: 4);
        },
      ),
    );
  }
}
