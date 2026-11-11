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

  /// Botón al inicio de la cabecera (por ejemplo "volver" en pantallas que se abren encima).
  final Widget? leading;
  const CabeceraSeccion({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.seccion,
    this.acciones = const [],
    this.leading,
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
                    if (leading != null) ...[leading!, const SizedBox(width: 4)],
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

/// Registros por página en todas las listas (coincide con el PAGE_SIZE del backend).
const tamanoPagina = 10;

int totalPaginasDe(int total) =>
    total <= 0 ? 1 : (total + tamanoPagina - 1) ~/ tamanoPagina;

/// Barra "‹ Página 2 de 5 ›" con el rango de registros que se está viendo.
/// No se dibuja si todo cabe en una sola página.
class PaginadorBarra extends StatelessWidget {
  final int pagina;
  final int totalPaginas;
  final int total;
  final bool cargando;
  final String? error;
  final ValueChanged<int> onIr;
  final VoidCallback? onReintentar;
  const PaginadorBarra({
    super.key,
    required this.pagina,
    required this.totalPaginas,
    required this.total,
    required this.onIr,
    this.cargando = false,
    this.error,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPaginas <= 1 && error == null) return const SizedBox(height: 4);
    final desde = (pagina - 1) * tamanoPagina + 1;
    final hasta = pagina * tamanoPagina < total ? pagina * tamanoPagina : total;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: 'Página anterior',
                onPressed: pagina > 1 && !cargando
                    ? () => onIr(pagina - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Página $pagina de $totalPaginas',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Página siguiente',
                onPressed: pagina < totalPaginas && !cargando
                    ? () => onIr(pagina + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          if (total > 0)
            Text(
              'Mostrando $desde–$hasta de $total',
              style: const TextStyle(color: Paleta.tintaSuave, fontSize: 12.5),
            ),
          if (error != null)
            TextButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('$error  ·  Reintentar'),
            ),
        ],
      ),
    );
  }
}

/// Lista de [tamanoPagina] registros por página, con botones para pasar de
/// página, pull-to-refresh y manejo de carga/vacío/error.
/// Si cambia [filtro] vuelve a la página 1; [ListaPaginadaState.recargar]
/// refresca la página actual.
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
  List<Map<String, dynamic>> _items = [];
  int _pagina = 1;
  int _pedida = 1; // página que se está pidiendo (para reintentar)
  int _total = 0;
  int _gen = 0; // descarta respuestas de cargas anteriores
  bool _cargando = false;
  bool _primera = true; // todavía no llegó ninguna página
  String? _error;

  @override
  void initState() {
    super.initState();
    _ir(1);
  }

  @override
  void didUpdateWidget(covariant ListaPaginada old) {
    super.didUpdateWidget(old);
    if (old.filtro != widget.filtro) {
      _items = [];
      _primera = true;
      _ir(1);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Vuelve a pedir la página que se está viendo.
  Future<void> recargar() => _ir(_pagina);

  Future<void> _ir(int pagina) async {
    final gen = ++_gen;
    _pedida = pagina;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final p = await widget.cargar(pagina);
      if (!mounted || gen != _gen) return;
      setState(() {
        _items = p.items;
        _total = p.total;
        _pagina = pagina;
        _primera = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } on PaginaInexistente {
      // Se borraron registros y esa página ya no existe: retrocede una.
      if (mounted && gen == _gen && pagina > 1) {
        await _ir(pagina - 1);
      }
      return;
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() => _error = mensajeError(e));
    } finally {
      if (mounted && gen == _gen) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_primera) {
      if (_error != null) {
        return EstadoError(mensaje: _error!, onReintentar: () => _ir(_pedida));
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      if (_error != null) {
        return EstadoError(mensaje: _error!, onReintentar: () => _ir(_pedida));
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
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: recargar,
          child: ListView.separated(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: _items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i < _items.length) {
                return widget.itemBuilder(context, _items[i]);
              }
              return PaginadorBarra(
                pagina: _pagina,
                totalPaginas: totalPaginasDe(_total),
                total: _total,
                cargando: _cargando,
                error: _error,
                onIr: _ir,
                onReintentar: () => _ir(_pedida),
              );
            },
          ),
        ),
        if (_cargando)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 3),
          ),
      ],
    );
  }
}
