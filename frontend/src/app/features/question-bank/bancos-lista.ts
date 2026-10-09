import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { Pagina } from '../../core/models/pagina';
import { mensajeError } from '../../core/utils/api-error';
import { Materia, MateriasService } from '../materias/materias.service';
import { Banco, BancosService } from './bancos.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-bancos-lista',
  imports: [RouterLink],
  template: `
    <h2>Bancos de preguntas</h2>

    <p><a routerLink="/bancos/nuevo">Nuevo banco</a></p>

    <form (submit)="buscar($event, q.value, materia.value, estado.value)">
      <input #q type="search" placeholder="Buscar por título o descripción" />
      <select #materia>
        <option value="">Todas las materias</option>
        @for (m of materias(); track m.id) {
          <option [value]="m.id">{{ m.nombre }}</option>
        }
      </select>
      <select #estado>
        <option value="">Todos</option>
        <option value="true">Activos</option>
        <option value="false">Inactivos</option>
      </select>
      <button type="submit">Buscar</button>
    </form>

    @if (error()) {
      <p role="alert">{{ error() }}</p>
    }

    @if (cargando()) {
      <p>Cargando…</p>
    } @else if (bancos().length === 0) {
      <p>No se encontraron bancos.</p>
    } @else {
      <table>
        <thead>
          <tr>
            <th>Título</th><th>Materia</th><th>Preguntas</th><th>Estado</th><th>Acciones</th>
          </tr>
        </thead>
        <tbody>
          @for (b of bancos(); track b.id) {
            <tr>
              <td>{{ b.titulo }}</td>
              <td>{{ b.materia_nombre }}</td>
              <td>{{ b.total_preguntas }}</td>
              <td>{{ b.activo ? 'Activo' : 'Inactivo' }}</td>
              <td>
                <a [routerLink]="['/bancos', b.id, 'editar']">Editar</a>
                @if (b.activo) {
                  <button type="button" (click)="desactivar(b)">Desactivar</button>
                }
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} bancos)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class BancosLista {
  private readonly servicio = inject(BancosService);
  private readonly materiasApi = inject(MateriasService);

  protected readonly bancos = signal<Banco[]>([]);
  protected readonly materias = signal<Materia[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';
  private materia?: number;
  private activo?: boolean;

  constructor() {
    this.materiasApi.listarTodas().subscribe({
      next: (m) => this.materias.set(m),
      error: (err) => this.error.set(mensajeError(err)),
    });
    this.cargar();
  }

  protected buscar(evento: Event, texto: string, materia: string, estado: string): void {
    evento.preventDefault();
    this.search = texto.trim();
    this.materia = materia === '' ? undefined : Number(materia);
    this.activo = estado === '' ? undefined : estado === 'true';
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected desactivar(b: Banco): void {
    if (!confirm(`¿Desactivar el banco "${b.titulo}"? Ya no se podrán agregar preguntas.`)) {
      return;
    }
    this.error.set('');
    this.servicio.desactivar(b.id).subscribe({
      next: () => this.cargar(),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio
      .listar({
        page: this.pagina(),
        search: this.search,
        materia: this.materia,
        activo: this.activo,
      })
      .subscribe({
        next: (r: Pagina<Banco>) => {
          this.bancos.set(r.results);
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