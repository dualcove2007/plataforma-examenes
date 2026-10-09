import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import {
  ESTADOS_REVISION,
  ETIQUETA_REVISION,
  EstadoRevision,
  Resultado,
  ResultadosService,
} from './resultados.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-resultados-lista',
  imports: [RouterLink],
  template: `
    <h2>Resultados</h2>

    <form (submit)="buscar($event, q.value, estado.value)">
      <input #q type="search" placeholder="Buscar por nombre o correo del estudiante" />
      <select #estado>
        <option value="">Todas las revisiones</option>
        @for (e of estados; track e.valor) {
          <option [value]="e.valor">{{ e.etiqueta }}</option>
        }
      </select>
      <button type="submit">Buscar</button>
    </form>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (resultados().length === 0) {
      <p>No se encontraron resultados.</p>
    } @else {
      <table>
        <thead>
          <tr>
            <th>Examen</th><th>Estudiante</th><th>Intento</th><th>Puntaje</th>
            <th>Nota</th><th>Revisión</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          @for (r of resultados(); track r.id) {
            <tr>
              <td>{{ r.examen_titulo }}</td>
              <td>{{ r.estudiante }}<br /><small>{{ r.estudiante_email }}</small></td>
              <td>{{ r.numero_intento }}</td>
              <td>{{ r.puntaje_total ?? 0 }} / {{ r.puntaje_maximo }}</td>
              <td>{{ r.nota_final ?? '—' }}</td>
              <td>{{ etiqueta[r.estado_revision] }}</td>
              <td>
                <a [routerLink]="['/resultados', r.id]">
                  {{ r.estado_revision === 'revisado' ? 'Ver' : 'Revisar' }}
                </a>
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} resultados)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class ResultadosLista {
  private readonly servicio = inject(ResultadosService);

  protected readonly estados = ESTADOS_REVISION;
  protected readonly etiqueta = ETIQUETA_REVISION;

  protected readonly resultados = signal<Resultado[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';
  private estado?: EstadoRevision;

  constructor() {
    this.cargar();
  }

  protected buscar(evento: Event, texto: string, estado: string): void {
    evento.preventDefault();
    this.search = texto.trim();
    this.estado = estado === '' ? undefined : (estado as EstadoRevision);
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio
      .listar({ page: this.pagina(), search: this.search, estado_revision: this.estado })
      .subscribe({
        next: (r) => {
          this.resultados.set(r.results);
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