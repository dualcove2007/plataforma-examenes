import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Pagina } from '../../core/models/pagina';
import { mensajeError } from '../../core/utils/api-error';
import { Materia, MateriasService } from './materias.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-materias-lista',
  imports: [RouterLink],
  template: `
    <h2>Materias</h2>

    <p><a routerLink="/materias/nueva">Nueva materia</a></p>

    <form (submit)="buscar($event, q.value)">
      <input #q type="search" placeholder="Buscar por nombre" />
      <button type="submit">Buscar</button>
    </form>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (materias().length === 0) {
      <p>No se encontraron materias.</p>
    } @else {
      <table>
        <thead>
          <tr><th>Nombre</th><th>Descripción</th><th>Acciones</th></tr>
        </thead>
        <tbody>
          @for (m of materias(); track m.id) {
            <tr>
              <td>{{ m.nombre }}</td>
              <td>{{ m.descripcion }}</td>
              <td>
                <a [routerLink]="['/materias', m.id, 'editar']">Editar</a>
                <button type="button" (click)="eliminar(m)">Eliminar</button>
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} materias)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class MateriasLista {
  private readonly servicio = inject(MateriasService);

  protected readonly materias = signal<Materia[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';

  constructor() {
    this.cargar();
  }

  protected buscar(evento: Event, texto: string): void {
    evento.preventDefault();
    this.search = texto.trim();
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected eliminar(m: Materia): void {
    if (!confirm(`¿Eliminar la materia "${m.nombre}"? Esta acción no se puede deshacer.`)) {
      return;
    }
    this.error.set('');
    this.servicio.eliminar(m.id).subscribe({
      next: () => {
        // Si era el único elemento de la última página, retrocede una página.
        if (this.materias().length === 1 && this.pagina() > 1) {
          this.pagina.update((p) => p - 1);
        }
        this.cargar();
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio.listar(this.pagina(), this.search).subscribe({
      next: (r: Pagina<Materia>) => {
        this.materias.set(r.results);
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