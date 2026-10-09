import { Component, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';

import { AuthService } from '../../core/services/auth.service';
import { mensajeError } from '../../core/utils/api-error';
import {
  Calificacion,
  ETIQUETA_REVISION,
  ResultadoDetalle,
  ResultadosService,
} from './resultados.service';

@Component({
  selector: 'app-resultado-revision',
  imports: [RouterLink],
  template: `
    <p><a routerLink="/resultados">← Volver a resultados</a></p>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }
    @if (aviso()) {
      <p role="status">{{ aviso() }}</p>
    }

    @if (resultado(); as r) {
      <h2>{{ r.examen_titulo }}</h2>
      <p>Estudiante: {{ r.estudiante }} ({{ r.estudiante_email }}) · Intento {{ r.numero_intento }}</p>
      <p>
        Revisión: <strong>{{ etiqueta[r.estado_revision] }}</strong> · Puntaje
        {{ r.puntaje_total ?? 0 }} / {{ r.puntaje_maximo }} · Nota {{ r.nota_final ?? '—' }}
      </p>

      <table>
        <thead>
          <tr><th>Pregunta</th><th>Respuesta del estudiante</th><th>Puntaje</th></tr>
        </thead>
        <tbody>
          @for (x of r.respuestas; track x.id) {
            <tr>
              <td>{{ x.enunciado }}</td>
              <td>
                @if (x.tipo === 'abierta') {
                  {{ x.texto_respuesta || '(sin respuesta)' }}
                } @else {
                  @for (o of x.opciones_seleccionadas; track o.id) {
                    <div>{{ o.texto }}</div>
                  } @empty {
                    (sin respuesta)
                  }
                }
              </td>
              <td>
                @if (calificable(x.id)) {
                  <input
                    type="number"
                    min="0"
                    [max]="x.puntaje_maximo ?? 0"
                    step="0.01"
                    [value]="notas()[x.id] ?? ''"
                    (input)="fijarNota(x.id, $event)"
                  />
                  / {{ x.puntaje_maximo }}
                } @else {
                  {{ x.puntaje_obtenido ?? 'Pendiente' }} / {{ x.puntaje_maximo }}
                }
              </td>
            </tr>
          }
        </tbody>
      </table>

      @if (abiertas().length > 0 && puedeCalificar()) {
        <button type="button" [disabled]="guardando()" (click)="guardar()">
          {{ guardando() ? 'Guardando…' : 'Guardar calificaciones' }}
        </button>
      }
    } @else if (!error()) {
      <p>Cargando…</p>
    }
  `,
})
export class ResultadoRevision {
  private readonly route = inject(ActivatedRoute);
  private readonly api = inject(ResultadosService);
  private readonly auth = inject(AuthService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id'));

  protected readonly etiqueta = ETIQUETA_REVISION;
  protected readonly resultado = signal<ResultadoDetalle | null>(null);
  protected readonly notas = signal<Record<number, string>>({});
  protected readonly guardando = signal(false);
  protected readonly error = signal('');
  protected readonly aviso = signal('');

  protected readonly puedeCalificar = computed(() =>
    this.auth.tienePermiso('resultados.calificar'),
  );

  /** Preguntas abiertas con texto: son las que el docente califica. */
  protected readonly abiertas = computed(
    () =>
      this.resultado()?.respuestas.filter(
        (x) => x.tipo === 'abierta' && x.texto_respuesta.trim() !== '',
      ) ?? [],
  );

  constructor() {
    this.cargar();
  }

  protected calificable(idRespuesta: number): boolean {
    return this.puedeCalificar() && this.abiertas().some((x) => x.id === idRespuesta);
  }

  protected fijarNota(idRespuesta: number, evento: Event): void {
    const valor = (evento.target as HTMLInputElement).value;
    this.notas.update((n) => ({ ...n, [idRespuesta]: valor }));
  }

  protected guardar(): void {
    const calificaciones: Calificacion[] = [];
    for (const x of this.abiertas()) {
      const texto = (this.notas()[x.id] ?? '').trim();
      if (texto === '') continue;
      const puntaje = Number(texto);
      const maximo = x.puntaje_maximo ?? 0;
      if (Number.isNaN(puntaje) || puntaje < 0 || puntaje > maximo) {
        this.error.set(`El puntaje de cada pregunta debe estar entre 0 y su máximo (${maximo}).`);
        return;
      }
      calificaciones.push({ respuesta: x.id, puntaje });
    }
    if (calificaciones.length === 0) {
      this.error.set('Escribe al menos un puntaje.');
      return;
    }

    this.error.set('');
    this.aviso.set('');
    this.guardando.set(true);
    this.api.calificar(this.id, calificaciones).subscribe({
      next: (r) => {
        this.aviso.set(
          r.estado_revision === 'revisado'
            ? 'Calificaciones guardadas. El resultado quedó revisado y el estudiante fue notificado.'
            : 'Calificaciones guardadas. Aún quedan preguntas por calificar.',
        );
        this.guardando.set(false);
        this.cargar();
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.guardando.set(false);
      },
    });
  }

  private cargar(): void {
    this.api.obtener(this.id).subscribe({
      next: (r) => {
        this.resultado.set(r);
        const mapa: Record<number, string> = {};
        for (const x of r.respuestas) {
          if (x.tipo === 'abierta' && x.puntaje_obtenido !== null) {
            mapa[x.id] = String(x.puntaje_obtenido);
          }
        }
        this.notas.set(mapa);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }
}