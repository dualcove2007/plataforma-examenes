import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { Notificacion, NotificacionesService } from './notificaciones.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-notificaciones',
  imports: [DatePipe],
  template: `
    <h2>Notificaciones</h2>

    <p>
      <label>
        Mostrar
        <select #filtro (change)="cambiarFiltro(filtro.value)">
          <option value="todas">Todas</option>
          <option value="no-leidas">Solo no leídas</option>
        </select>
      </label>
      <button type="button" (click)="marcarTodas()">Marcar todas como leídas</button>
    </p>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (items().length === 0) {
      <p>No tienes notificaciones.</p>
    } @else {
      <ul>
        @for (n of items(); track n.id) {
          <li>
            <strong>{{ n.titulo }}</strong>
            @if (!n.leida) {
              <span> · Nueva</span>
            }
            <p>{{ n.mensaje }}</p>
            <small>{{ n.fecha_creacion | date: 'dd/MM/yyyy HH:mm' }}</small>
            <div>
              @if (destino(n)) {
                <button type="button" (click)="abrir(n)">Abrir</button>
              }
              @if (!n.leida) {
                <button type="button" (click)="marcar(n)">Marcar como leída</button>
              }
            </div>
          </li>
        }
      </ul>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }})</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class Notificaciones {
  private readonly api = inject(NotificacionesService);
  private readonly router = inject(Router);

  protected readonly items = signal<Notificacion[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private soloNoLeidas = false;

  constructor() {
    this.cargar();
  }

  protected cambiarFiltro(valor: string): void {
    this.soloNoLeidas = valor === 'no-leidas';
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  /** A dónde lleva cada notificación; null si no tiene destino. */
  protected destino(n: Notificacion): string[] | null {
    if (n.entidad === 'Resultado') return ['/mis-resultados', n.entidad_id];
    if (n.entidad === 'Examen') return ['/mis-examenes'];
    return null;
  }

  protected abrir(n: Notificacion): void {
    const ruta = this.destino(n);
    if (!ruta) return;
    const ir = () => void this.router.navigate(ruta);
    if (n.leida) {
      ir();
      return;
    }
    this.api.marcarLeida(n.id).subscribe({ next: ir, error: ir });
  }

  protected marcar(n: Notificacion): void {
    this.error.set('');
    this.api.marcarLeida(n.id).subscribe({
      next: (actualizada) =>
        this.items.update((lista) => lista.map((x) => (x.id === n.id ? actualizada : x))),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  protected marcarTodas(): void {
    this.error.set('');
    this.api.marcarTodas().subscribe({
      next: () => this.cargar(),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.api.listar(this.pagina(), this.soloNoLeidas).subscribe({
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