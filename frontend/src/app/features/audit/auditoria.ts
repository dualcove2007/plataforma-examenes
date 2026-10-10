import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';

import { Pagina } from '../../core/models/pagina';
import { mensajeError } from '../../core/utils/api-error';
import { AuditoriaService, RecursoAuditoria } from './auditoria.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-auditoria',
  imports: [DatePipe],
  template: `
    <h2>Auditoría</h2>

    <nav aria-label="Tipo de registro">
      <button type="button" [disabled]="recurso() === 'auditoria'" (click)="cambiar('auditoria')">
        Acciones
      </button>
      <button type="button" [disabled]="recurso() === 'historial'" (click)="cambiar('historial')">
        Cambios de campos
      </button>
      <button
        type="button"
        [disabled]="recurso() === 'historial-estados'"
        (click)="cambiar('historial-estados')"
      >
        Cambios de estado
      </button>
    </nav>

    <form (submit)="buscar($event, q.value, desde.value, hasta.value, orden.value)">
      <input #q type="search" placeholder="Buscar (usuario, entidad, campo…)" />
      <label>Desde <input #desde type="date" /></label>
      <label>Hasta <input #hasta type="date" /></label>
      <select #orden>
        <option value="-fecha">Más recientes</option>
        <option value="fecha">Más antiguos</option>
      </select>
      <button type="submit">Filtrar</button>
    </form>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p role="status">Cargando…</p>
    } @else if (filas().length === 0) {
      <p>No hay registros.</p>
    } @else {
      <table>
        <thead>
          @switch (recurso()) {
            @case ('auditoria') {
              <tr>
                <th>Fecha</th><th>Usuario</th><th>Acción</th><th>Entidad</th><th>ID</th><th>IP</th>
              </tr>
            }
            @case ('historial') {
              <tr>
                <th>Fecha</th><th>Usuario</th><th>Entidad</th><th>ID</th>
                <th>Campo</th><th>Antes</th><th>Después</th>
              </tr>
            }
            @default {
              <tr>
                <th>Fecha</th><th>Usuario</th><th>Entidad</th><th>ID</th>
                <th>Estado anterior</th><th>Estado nuevo</th>
              </tr>
            }
          }
        </thead>
        <tbody>
          @for (f of filas(); track f.id) {
            <tr>
              <td>{{ f.fecha | date: 'dd/MM/yyyy HH:mm' }}</td>
              <td>{{ f.usuario_nombre ?? '—' }}</td>
              @switch (recurso()) {
                @case ('auditoria') {
                  <td>{{ f.accion }}</td>
                  <td>{{ f.entidad }}</td>
                  <td>{{ f.entidad_id }}</td>
                  <td>{{ f.ip_address ?? '—' }}</td>
                }
                @case ('historial') {
                  <td>{{ f.entidad }}</td>
                  <td>{{ f.entidad_id }}</td>
                  <td>{{ f.campo }}</td>
                  <td>{{ f.valor_anterior ?? '—' }}</td>
                  <td>{{ f.valor_nuevo ?? '—' }}</td>
                }
                @default {
                  <td>{{ f.entidad }}</td>
                  <td>{{ f.entidad_id }}</td>
                  <td>{{ f.estado_anterior || '—' }}</td>
                  <td>{{ f.estado_nuevo }}</td>
                }
              }
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} registros)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">
          Siguiente
        </button>
      </nav>
    }
  `,
})
export class Auditoria {
  private readonly servicio = inject(AuditoriaService);

  // Las tres tablas tienen columnas distintas; se tipa como any para una sola plantilla.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  protected readonly filas = signal<any[]>([]);
  protected readonly recurso = signal<RecursoAuditoria>('auditoria');
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';
  private desde = '';
  private hasta = '';
  private ordering = '-fecha';

  constructor() {
    this.cargar();
  }

  protected cambiar(r: RecursoAuditoria): void {
    this.recurso.set(r);
    this.pagina.set(1);
    this.cargar();
  }

  protected buscar(e: Event, q: string, desde: string, hasta: string, orden: string): void {
    e.preventDefault();
    this.search = q.trim();
    this.desde = desde;
    this.hasta = hasta;
    this.ordering = orden;
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(p: number): void {
    this.pagina.set(p);
    this.cargar();
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio
      .listar(this.recurso(), {
        page: this.pagina(),
        search: this.search,
        desde: this.desde,
        hasta: this.hasta,
        ordering: this.ordering,
      })
      .subscribe({
        next: (r: Pagina<unknown>) => {
          this.filas.set(r.results);
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