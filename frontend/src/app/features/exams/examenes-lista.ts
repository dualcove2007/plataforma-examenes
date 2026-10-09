import { DatePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Pagina } from '../../core/models/pagina';
import { mensajeError } from '../../core/utils/api-error';
import {
  AccionEstado,
  ESTADOS_EXAMEN,
  ETIQUETA_ESTADO_EXAMEN,
  EstadoExamen,
  Examen,
  ExamenesService,
} from './examenes.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-examenes-lista',
  imports: [RouterLink, DatePipe],
  template: `
    <h2>Exámenes</h2>

    <p><a routerLink="/examenes/nuevo">Nuevo examen</a></p>

    <form (submit)="buscar($event, q.value, estado.value)">
      <input #q type="search" placeholder="Buscar por título o descripción" />
      <select #estado>
        <option value="">Todos los estados</option>
        @for (e of estados; track e.valor) {
          <option [value]="e.valor">{{ e.etiqueta }}</option>
        }
      </select>
      <button type="submit">Buscar</button>
    </form>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }
    @if (aviso()) {
      <p role="status">{{ aviso() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (examenes().length === 0) {
      <p>No se encontraron exámenes.</p>
    } @else {
      <table>
        <thead>
          <tr>
            <th>Título</th><th>Materia</th><th>Inicio</th><th>Fin</th>
            <th>Duración</th><th>Preguntas</th><th>Estado</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          @for (e of examenes(); track e.id) {
            <tr>
              <td>{{ e.titulo }}</td>
              <td>{{ e.materia_nombre }}</td>
              <td>{{ e.fecha_inicio | date: 'dd/MM/yyyy HH:mm' }}</td>
              <td>{{ e.fecha_fin | date: 'dd/MM/yyyy HH:mm' }}</td>
              <td>{{ e.duracion_minutos }} min</td>
              <td>{{ e.total_preguntas }}</td>
              <td>{{ etiquetaEstado[e.estado] }}</td>
              <td>
                @if (e.estado === 'borrador') {
                  <a [routerLink]="['/examenes', e.id, 'editar']">Editar</a>
                  <button type="button" (click)="cambiarEstado(e, 'publicar')">Publicar</button>
                  <button type="button" (click)="eliminar(e)">Eliminar</button>
                }
                @if (e.estado === 'publicado') {
                  <button type="button" (click)="cambiarEstado(e, 'cerrar')">Cerrar</button>
                }
                @if (e.estado === 'borrador' || e.estado === 'cerrado') {
                  <button type="button" (click)="cambiarEstado(e, 'archivar')">Archivar</button>
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
export class ExamenesLista {
  private readonly servicio = inject(ExamenesService);

  protected readonly estados = ESTADOS_EXAMEN;
  protected readonly etiquetaEstado = ETIQUETA_ESTADO_EXAMEN;

  protected readonly examenes = signal<Examen[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly aviso = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';
  private estado?: EstadoExamen;

  constructor() {
    this.cargar();
  }

  protected buscar(evento: Event, texto: string, estado: string): void {
    evento.preventDefault();
    this.search = texto.trim();
    this.estado = estado === '' ? undefined : (estado as EstadoExamen);
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected cambiarEstado(e: Examen, accion: AccionEstado): void {
    const verbo = { publicar: 'publicar', cerrar: 'cerrar', archivar: 'archivar' }[accion];
    if (!confirm(`¿Seguro que quieres ${verbo} el examen «${e.titulo}»?`)) return;
    this.error.set('');
    this.aviso.set('');
    this.servicio.cambiarEstado(e.id, accion).subscribe({
      next: (r) => {
        this.aviso.set(`El examen quedó en estado «${this.etiquetaEstado[r.estado]}».`);
        this.cargar();
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  protected eliminar(e: Examen): void {
    if (!confirm(`¿Eliminar el examen «${e.titulo}»? Esta acción no se puede deshacer.`)) return;
    this.error.set('');
    this.aviso.set('');
    this.servicio.eliminar(e.id).subscribe({
      next: () => {
        this.aviso.set('Examen eliminado.');
        if (this.examenes().length === 1 && this.pagina() > 1) {
          this.pagina.update((n) => n - 1);
        }
        this.cargar();
      },
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio
      .listar({ page: this.pagina(), search: this.search, estado: this.estado })
      .subscribe({
        next: (r: Pagina<Examen>) => {
          this.examenes.set(r.results);
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