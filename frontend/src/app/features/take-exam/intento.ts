import { Component, DestroyRef, computed, inject, signal } from '@angular/core';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { catchError, forkJoin, of, switchMap } from 'rxjs';
import { Adjuntos } from '../adjuntos/adjuntos';

import { mensajeError } from '../../core/utils/api-error';
import {
  CuerpoRespuesta,
  Intento,
  IntentosService,
  PreguntaIntento,
  ResultadoIntento,
} from './intentos.service';

interface RespuestaLocal {
  opciones: number[];
  texto: string;
}

const dos = (n: number) => String(n).padStart(2, '0');

@Component({
  selector: 'app-intento',
  imports: [RouterLink, Adjuntos],
  template: `
    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (resultado(); as r) {
      <h2>Examen enviado</h2>
      <p>{{ r.examen_titulo }}</p>
      @if (r.nota_final !== null) {
        <p>
          Tu nota: <strong>{{ r.nota_final }}</strong> (puntaje {{ r.puntaje_total }} de
          {{ r.puntaje_maximo }})
        </p>
      } @else {
        <p>Tu resultado estará disponible cuando el docente termine la revisión.</p>
      }
      <p><a routerLink="/mis-examenes">Volver a mis exámenes</a></p>
    } @else if (intento(); as i) {
      @if (i.estado === 'en_progreso' && i.preguntas) {
        <h2>{{ i.titulo }}</h2>
        <p>
          Tiempo restante: <strong>{{ tiempo() }}</strong> · Respondidas
          {{ respondidas() }} de {{ i.preguntas.length }}
        </p>
        <app-adjuntos tipo="examen" [objetoId]="i.examen" [soloLectura]="true" />

        @for (p of i.preguntas; track p.pregunta) {
          <fieldset>
            <legend>{{ p.orden }}. {{ p.enunciado }} ({{ p.puntaje }} pts)</legend>
            <app-adjuntos tipo="pregunta" [objetoId]="p.pregunta" [soloLectura]="true" />

            @if (p.tipo === 'abierta') {
              <textarea
                rows="4"
                [value]="texto(p.pregunta)"
                (input)="cambiarTexto(p, $event)"
                (blur)="guardar(p)"
              ></textarea>
            } @else if (p.tipo === 'opcion_multiple') {
              @for (o of p.opciones; track o.id) {
                <label>
                  <input
                    type="checkbox"
                    [checked]="seleccion(p.pregunta).includes(o.id)"
                    (change)="alternar(p, o.id, $event)"
                  />
                  {{ o.texto }}
                </label>
              }
            } @else {
              @for (o of p.opciones; track o.id) {
                <label>
                  <input
                    type="radio"
                    [name]="'p' + p.pregunta"
                    [checked]="seleccion(p.pregunta).includes(o.id)"
                    (change)="elegirUna(p, o.id)"
                  />
                  {{ o.texto }}
                </label>
              }
            }
          </fieldset>
        }

        @if (estadoGuardado()) {
          <p role="status">{{ estadoGuardado() }}</p>
        }
        <button type="button" [disabled]="enviando()" (click)="enviar()">
          {{ enviando() ? 'Enviando…' : 'Enviar examen' }}
        </button>
      } @else {
        <p>Este intento ya no está en progreso (estado: {{ i.estado }}).</p>
        <p><a routerLink="/mis-examenes">Volver a mis exámenes</a></p>
      }
    }
  `,
})
export class IntentoExamen {
  private readonly route = inject(ActivatedRoute);
  private readonly api = inject(IntentosService);
  private readonly destroyRef = inject(DestroyRef);

  private readonly id = Number(this.route.snapshot.paramMap.get('id'));

  protected readonly intento = signal<Intento | null>(null);
  protected readonly respuestas = signal<Record<number, RespuestaLocal>>({});
  protected readonly restantes = signal(0);
  protected readonly resultado = signal<ResultadoIntento | null>(null);
  protected readonly cargando = signal(true);
  protected readonly enviando = signal(false);
  protected readonly error = signal('');
  protected readonly estadoGuardado = signal('');

  protected readonly tiempo = computed(() => {
    const s = Math.max(0, this.restantes());
    return `${dos(Math.floor(s / 60))}:${dos(s % 60)}`;
  });

  protected readonly respondidas = computed(() => {
    const r = this.respuestas();
    return (this.intento()?.preguntas ?? []).filter((p) => {
      const x = r[p.pregunta];
      return !!x && (x.opciones.length > 0 || x.texto.trim() !== '');
    }).length;
  });

  private reloj?: ReturnType<typeof setInterval>;

  constructor() {
    this.destroyRef.onDestroy(() => this.detenerReloj());

    this.api.obtener(this.id).subscribe({
      next: (i) => {
        this.intento.set(i);
        this.cargando.set(false);
        if (i.estado === 'en_progreso' && i.preguntas) {
          const mapa: Record<number, RespuestaLocal> = {};
          for (const p of i.preguntas) {
            if (p.respuesta) {
              mapa[p.pregunta] = {
                opciones: p.respuesta.opciones,
                texto: p.respuesta.texto_respuesta,
              };
            }
          }
          this.respuestas.set(mapa);
          this.restantes.set(i.segundos_restantes);
          this.iniciarReloj();
        }
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.cargando.set(false);
      },
    });
  }

  // ---------------- lectura de respuestas locales ----------------
  protected seleccion(id: number): number[] {
    return this.respuestas()[id]?.opciones ?? [];
  }

  protected texto(id: number): string {
    return this.respuestas()[id]?.texto ?? '';
  }

  // ---------------- cambios del estudiante ----------------
  protected elegirUna(p: PreguntaIntento, opcionId: number): void {
    this.fijar(p.pregunta, { opciones: [opcionId] });
    this.guardar(p);
  }

  protected alternar(p: PreguntaIntento, opcionId: number, evento: Event): void {
    const marcada = (evento.target as HTMLInputElement).checked;
    const otras = this.seleccion(p.pregunta).filter((x) => x !== opcionId);
    this.fijar(p.pregunta, { opciones: marcada ? [...otras, opcionId] : otras });
    this.guardar(p);
  }

  protected cambiarTexto(p: PreguntaIntento, evento: Event): void {
    this.fijar(p.pregunta, { texto: (evento.target as HTMLTextAreaElement).value });
  }

  private fijar(id: number, cambio: Partial<RespuestaLocal>): void {
    this.respuestas.update((r) => {
      const actual: RespuestaLocal = r[id] ?? { opciones: [], texto: '' };
      return { ...r, [id]: { ...actual, ...cambio } };
    });
  }

  // ---------------- guardado y envío ----------------
  private cuerpo(p: PreguntaIntento): CuerpoRespuesta {
    const r = this.respuestas()[p.pregunta];
    const abierta = p.tipo === 'abierta';
    return {
      pregunta: p.pregunta,
      opciones: abierta ? [] : (r?.opciones ?? []),
      texto_respuesta: abierta ? (r?.texto ?? '') : '',
    };
  }

  protected guardar(p: PreguntaIntento): void {
    this.error.set('');
    this.estadoGuardado.set('Guardando…');
    this.api.responder(this.id, this.cuerpo(p)).subscribe({
      next: (r) => {
        this.restantes.set(r.segundos_restantes);
        this.estadoGuardado.set('Respuesta guardada.');
      },
      error: (err) => {
        this.estadoGuardado.set('');
        this.error.set(mensajeError(err));
      },
    });
  }

  protected enviar(auto = false): void {
    if (this.enviando()) return;
    if (!auto && !confirm('¿Enviar el examen? Ya no podrás cambiar tus respuestas.')) return;

    this.enviando.set(true);
    this.error.set('');
    this.detenerReloj();

    // Las respuestas abiertas se guardan al salir del cuadro; aquí se asegura la última.
    const abiertas = (this.intento()?.preguntas ?? []).filter(
      (p) => p.tipo === 'abierta' && this.texto(p.pregunta).trim() !== '',
    );
    const guardado$ = abiertas.length
      ? forkJoin(
          abiertas.map((p) =>
            this.api.responder(this.id, this.cuerpo(p)).pipe(catchError(() => of(null))),
          ),
        )
      : of([]);

    guardado$.pipe(switchMap(() => this.api.enviar(this.id))).subscribe({
      next: (r) => {
        this.resultado.set(r);
        this.enviando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.enviando.set(false);
        if (this.restantes() > 0) this.iniciarReloj();
      },
    });
  }

  // ---------------- reloj ----------------
  private iniciarReloj(): void {
    this.detenerReloj();
    this.reloj = setInterval(() => {
      this.restantes.update((n) => n - 1);
      if (this.restantes() <= 0) {
        this.detenerReloj();
        this.enviar(true); // se acabó el tiempo: envío automático
      }
    }, 1000);
  }

  private detenerReloj(): void {
    if (this.reloj !== undefined) {
      clearInterval(this.reloj);
      this.reloj = undefined;
    }
  }
}