import { Component, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { guardarArchivo } from '../../core/utils/descargar';
import {
  MiResultadoDetalle,
  MisResultadosService,
  RespuestaEstudiante,
} from './mis-resultados.service';
import { ETIQUETA_REVISION } from './resultados.service';

@Component({
  selector: 'app-mi-resultado',
  imports: [RouterLink],
  template: `
    <p><a routerLink="/mis-resultados">← Volver a mis resultados</a></p>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (resultado(); as r) {
      <h2>{{ r.examen_titulo }}</h2>
      <p>Intento {{ r.numero_intento }} · Revisión: {{ etiqueta[r.estado_revision] }}</p>

      @if (r.nota_final !== null) {
        <p>
          Nota: <strong>{{ r.nota_final }}</strong> · Puntaje {{ r.puntaje_total }} /
          {{ r.puntaje_maximo }}
        </p>
      } @else {
        <p>Tu nota estará disponible cuando el docente termine la revisión.</p>
      }

      @if (r.estado_revision === 'revisado') {
        <button type="button" (click)="constancia(r)">Descargar constancia (PDF)</button>
      }

      @if (r.respuestas; as respuestas) {
        <h3>Detalle de tus respuestas</h3>
        @for (x of respuestas; track x.id) {
          <fieldset>
            <legend>{{ $index + 1 }}. {{ x.enunciado }}</legend>

            <p>
              <strong>Tu respuesta:</strong>
              @if (x.tipo === 'abierta') {
                {{ x.texto_respuesta || '(sin respuesta)' }}
              } @else {
                @for (o of x.opciones_seleccionadas; track o.id) {
                  <span>{{ o.texto }}{{ $last ? '' : ', ' }}</span>
                } @empty {
                  (sin respuesta)
                }
              }
            </p>

            @if (x.tipo !== 'abierta') {
              <p>
                <strong>Respuesta correcta:</strong>
                @for (o of x.opciones_correctas; track o.id) {
                  <span>{{ o.texto }}{{ $last ? '' : ', ' }}</span>
                }
              </p>
            }

            <p>
              Puntaje: {{ x.puntaje_obtenido ?? 0 }} / {{ x.puntaje_maximo }} ·
              {{ veredicto(x) }}
            </p>
          </fieldset>
        }
      } @else if (r.estado_revision === 'revisado') {
        <p>El detalle de las respuestas estará disponible cuando el examen sea cerrado.</p>
      }
    } @else if (!error()) {
      <p>Cargando…</p>
    }
  `,
})
export class MiResultado {
  private readonly route = inject(ActivatedRoute);
  private readonly api = inject(MisResultadosService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id'));

  protected readonly etiqueta = ETIQUETA_REVISION;
  protected readonly resultado = signal<MiResultadoDetalle | null>(null);
  protected readonly error = signal('');

  constructor() {
    this.api.obtener(this.id).subscribe({
      next: (r) => this.resultado.set(r),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  protected veredicto(x: RespuestaEstudiante): string {
    const obtenido = x.puntaje_obtenido ?? 0;
    const maximo = x.puntaje_maximo ?? 0;
    if (maximo > 0 && obtenido >= maximo) return 'Correcta';
    return obtenido > 0 ? 'Parcialmente correcta' : 'Incorrecta';
  }

  protected constancia(r: MiResultadoDetalle): void {
    this.error.set('');
    this.api.constancia(r.id).subscribe({
      next: (b) => guardarArchivo(b, `constancia_resultado_${r.id}.pdf`),
      error: () => this.error.set('No se pudo descargar la constancia.'),
    });
  }
}