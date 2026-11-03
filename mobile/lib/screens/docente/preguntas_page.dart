import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/docente_ui.dart';
import '../../widgets/ui.dart';
import 'pregunta_form_page.dart';

/// Preguntas de un banco. Se abre encima de la lista de bancos.
class PreguntasPage extends StatefulWidget {
  final ApiService api;
  final Map<String, dynamic> banco;
  const PreguntasPage({super.key, required this.api, required this.banco});

  @override
  State<PreguntasPage> createState() => _PreguntasPageState();
}

class _PreguntasPageState extends State<PreguntasPage> {
  final _lista = GlobalKey<ListaPaginadaState>();
  String _buscar = '';
  String? _tipo;

  int get _bancoId => widget.banco['id'] as int;

  Future<void> _abrirForm([Map<String, dynamic>? pregunta]) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreguntaFormPage(
          api: widget.api,
          banco: widget.banco,
          pregunta: pregunta,
        ),
      ),
    );
    if (ok == true) _lista.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    final bancoActivo = widget.banco['activo'] != false;
    return Scaffold(
      floatingActionButton: bancoActivo
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed: () => _abrirForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva pregunta'),
            )
          : null,
      body: Column(
        children: [
          CabeceraSeccion(
            titulo: '${widget.banco['titulo']}',
            subtitulo: '${widget.banco['materia_nombre'] ?? 'Preguntas'}',
            icono: Icons.quiz_rounded,
            seccion: Seccion.catalogo,
            leading: botonVolver(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: CampoBusqueda(
              hint: 'Buscar en los enunciados',
              onCambio: (v) => setState(() => _buscar = v),
            ),
          ),
          FilaFiltros<String?>(
            opciones: [
              const OpcionFiltro('Todas', null, Icons.layers_rounded),
              for (final e in tiposPregunta.entries)
                OpcionFiltro(e.value.texto, e.key, e.value.icono),
            ],
            valor: _tipo,
            onCambio: (v) => setState(() => _tipo = v),
          ),
          Expanded(
            child: ListaPaginada(
              key: _lista,
              filtro: '$_buscar|$_tipo',
              cargar: (p) => widget.api.preguntasPagina(
                p,
                banco: _bancoId,
                buscar: _buscar,
                tipo: _tipo,
              ),
              itemBuilder: (_, p) {
                final tipo = estiloTipo('${p['tipo']}');
                final dif = estiloDificultad('${p['dificultad']}');
                final activa = p['activo'] != false;
                return PanelCard(
                  onTap: () => _abrirForm(p),
                  color: activa ? Colors.white : Paleta.crema,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(tipo.icono, fondo: tipo.suave, tam: 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${p['enunciado']}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: activa ? Paleta.tinta : Paleta.tintaSuave,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Etiqueta(tipo.texto, fondo: tipo.suave),
                                Etiqueta(
                                  dif.texto,
                                  icono: dif.icono,
                                  fondo: dif.suave,
                                ),
                                Etiqueta(
                                  '${formatearPuntaje(p['puntaje'])} pts',
                                  icono: Icons.star_rounded,
                                  fondo: Paleta.crema,
                                ),
                                if (!activa)
                                  const Etiqueta(
                                    'Inactiva',
                                    icono: Icons.block_rounded,
                                    fondo: Paleta.coralSuave,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Paleta.tintaSuave,
                      ),
                    ],
                  ),
                );
              },
              vacio: EstadoVacio(
                titulo: 'Este banco no tiene preguntas',
                mensaje: bancoActivo
                    ? 'Agrega la primera con el botón “Nueva pregunta”.'
                    : 'El banco está inactivo y no admite preguntas nuevas.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
