import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { IntentosService } from './intentos.service';
import { ETIQUETA_ASIGNACION, MiExamen, MisExamenesService } from './mis-examenes.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-mis-examenes',
  imports: [DatePipe],
  template: `
    <h2>Mis exámenes</h2>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (items().length === 0) {
      <p>No tienes exámenes asignados.</p>
    } @else {
      <table>
        <thead>
          <tr>
            <th>Examen</th><th>Materia</th><th>Disponible</th><th>Duración</th>
            <th>Intentos</th><th>Estado</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          @for (a of items(); track a.id) {
            <tr>
              <td>{{ a.titulo }}</td>
              <td>{{ a.materia }}</td>
              <td>
                {{ a.fecha_inicio | date: 'dd/MM/yyyy HH:mm' }} –
                {{ a.fecha_fin | date: 'dd/MM/yyyy HH:mm' }}
              </td>
              <td>{{ a.duracion_minutos }} min · {{ a.total_preguntas }} preguntas</td>
              <td>{{ a.intentos_permitidos }}</td>
              <td>{{ etiqueta[a.estado] }}</td>
              <td>
                @if (puedeRendir(a)) {
                  <button type="button" [disabled]="iniciando() !== null" (click)="rendir(a)">
                    {{ iniciando() === a.id ? 'Abriendo…' : a.estado === 'en_progreso' ? 'Continuar' : 'Rendir' }}
                  </button>
                }
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} exámenes)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class MisExamenes {
  private readonly api = inject(MisExamenesService);
  private readonly intentos = inject(IntentosService);
  private readonly router = inject(Router);

  protected readonly etiqueta = ETIQUETA_ASIGNACION;

  protected readonly items = signal<MiExamen[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly iniciando = signal<number | null>(null);
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  constructor() {
    this.cargar();
  }

  protected puedeRendir(a: MiExamen): boolean {
    return a.examen_estado === 'publicado' && a.estado !== 'vencido';
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected rendir(a: MiExamen): void {
    if (
      a.estado !== 'en_progreso' &&
      !confirm(`¿Iniciar «${a.titulo}»? El tiempo (${a.duracion_minutos} min) empieza a correr.`)
    ) {
      return;
    }
    this.error.set('');
    this.iniciando.set(a.id);
    this.intentos.iniciar(a.id).subscribe({
      next: (i) => void this.router.navigate(['/intentos', i.id]),
      error: (err) => {
        this.error.set(mensajeError(err));
        this.iniciando.set(null);
      },
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.api.listar(this.pagina()).subscribe({
      next: (r) => {
        this.items.set(r.results);
        this.total.set(r.count);
        this.cargando.set(false);
      },
      error: (err) => {
        this.error.set(mensajeError(err));
        this.cargando.set(false);
      },
    });
  }
}