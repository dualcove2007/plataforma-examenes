import { Component, computed, effect, inject, input, signal } from '@angular/core';

import { mensajeError } from '../../core/utils/api-error';
import { guardarArchivo } from '../../core/utils/descargar';
import { Adjunto, AdjuntosService, DuenoAdjunto } from './adjuntos.service';

const MB = 1024 * 1024;
// Mismos límites que backend/apps/files/validators.py (el backend siempre revalida).
const LIMITES: Record<string, number> = {
  pdf: 10 * MB,
  png: 5 * MB,
  jpg: 5 * MB,
  jpeg: 5 * MB,
};

@Component({
  selector: 'app-adjuntos',
    template: `
    @if (visible()) {
      <section aria-label="Adjuntos">
        <h3>{{ soloLectura() ? 'Material adjunto' : 'Adjuntos' }}</h3>

        @if (error()) {
          <p role="alert">{{ error() }}</p>
        }

        @if (cargando()) {
          <p role="status">Cargando adjuntos…</p>
        } @else {
          <ul>
            @for (a of adjuntos(); track a.id) {
              <li>
                {{ a.nombre_original }} ({{ tamano(a.tamano) }})
                <button type="button" (click)="descargar(a)">Descargar</button>
                @if (!soloLectura()) {
                  <button type="button" (click)="eliminar(a)" [disabled]="trabajando()">
                    Eliminar
                  </button>
                }
              </li>
            } @empty {
              <li>Sin adjuntos.</li>
            }
          </ul>
        }

        @if (!soloLectura()) {
          <p>
            <label>
              Nuevo adjunto (PDF máx. 10 MB; PNG/JPG máx. 5 MB)
              <input #selector type="file" accept=".pdf,.png,.jpg,.jpeg" />
            </label>
            <button type="button" (click)="subir(selector)" [disabled]="trabajando()">
              {{ trabajando() ? 'Subiendo…' : 'Subir' }}
            </button>
          </p>
        }
      </section>
    }`,
})
export class Adjuntos {
  private readonly api = inject(AdjuntosService);

  readonly tipo = input.required<DuenoAdjunto>();
  readonly objetoId = input.required<number>();
  readonly soloLectura = input(false);

  /** En solo lectura no se muestra nada si no hay adjuntos (ni mientras carga). */
  protected readonly visible = computed(
    () => !this.soloLectura() || this.adjuntos().length > 0 || !!this.error(),
  );

  protected readonly adjuntos = signal<Adjunto[]>([]);
  protected readonly cargando = signal(false);
  protected readonly trabajando = signal(false);
  protected readonly error = signal('');

  constructor() {
    effect(() => {
      this.tipo();
      this.objetoId();
      this.cargar();
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.api.listar(this.tipo(), this.objetoId()).subscribe({
      next: (lista) => {
        this.adjuntos.set(lista);
        this.cargando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.cargando.set(false);
      },
    });
  }

  protected tamano(bytes: number): string {
    return bytes >= MB ? `${(bytes / MB).toFixed(1)} MB` : `${Math.max(1, Math.round(bytes / 1024))} KB`;
  }

  protected subir(selector: HTMLInputElement): void {
    this.error.set('');
    const archivo = selector.files?.[0];
    if (!archivo) {
      this.error.set('Selecciona un archivo.');
      return;
    }
    const extension = archivo.name.split('.').pop()?.toLowerCase() ?? '';
    const maximo = LIMITES[extension];
    if (!maximo) {
      this.error.set('Tipo de archivo no permitido. Solo PDF, PNG o JPG.');
      return;
    }
    if (archivo.size === 0) {
      this.error.set('El archivo está vacío.');
      return;
    }
    if (archivo.size > maximo) {
      this.error.set(`El archivo supera el máximo de ${maximo / MB} MB para este tipo.`);
      return;
    }

    this.trabajando.set(true);
    this.api.subir(this.tipo(), this.objetoId(), archivo).subscribe({
      next: (nuevo) => {
        this.adjuntos.update((lista) => [nuevo, ...lista]);
        selector.value = '';
        this.trabajando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.trabajando.set(false);
      },
    });
  }

  protected descargar(a: Adjunto): void {
    this.error.set('');
    this.api.descargar(a.id).subscribe({
      next: (blob) => guardarArchivo(blob, a.nombre_original),
      error: () => this.error.set('No se pudo descargar el archivo.'),
    });
  }

  protected eliminar(a: Adjunto): void {
    if (!confirm(`¿Eliminar "${a.nombre_original}"?`)) return;
    this.error.set('');
    this.trabajando.set(true);
    this.api.eliminar(a.id).subscribe({
      next: () => {
        this.adjuntos.update((lista) => lista.filter((x) => x.id !== a.id));
        this.trabajando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.trabajando.set(false);
      },
    });
  }
}