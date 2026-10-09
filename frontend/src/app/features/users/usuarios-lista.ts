import { Component, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { Pagina } from '../../core/models/pagina';
import { UsuarioLista, UsuariosService } from './usuarios.service';

const TAMANO_PAGINA = 10;

@Component({
  selector: 'app-usuarios-lista',
  imports: [RouterLink],
  template: `
    <h2>Usuarios</h2>

    <p><a routerLink="/usuarios/nuevo">Nuevo usuario</a></p>

    <form (submit)="buscar($event, q.value, estado.value)">
      <input #q type="search" placeholder="Buscar por nombre o correo" />
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
    } @else if (usuarios().length === 0) {
      <p>No se encontraron usuarios.</p>
    } @else {
      <table>
        <thead>
          <tr><th>Nombre</th><th>Correo</th><th>Rol</th><th>Estado</th><th>Acciones</th></tr>
        </thead>
        <tbody>
          @for (u of usuarios(); track u.id) {
            <tr>
              <td>{{ u.nombre }}</td>
              <td>{{ u.email }}</td>
              <td>{{ u.rol_nombre }}</td>
              <td>{{ u.activo ? 'Activo' : 'Inactivo' }}</td>
              <td>
                <a [routerLink]="['/usuarios', u.id, 'editar']">Editar</a>
                @if (u.activo) {
                  <button type="button" (click)="desactivar(u)">Desactivar</button>
                }
              </td>
            </tr>
          }
        </tbody>
      </table>

      <nav aria-label="Paginación">
        <button type="button" [disabled]="pagina() <= 1" (click)="irA(pagina() - 1)">Anterior</button>
        <span>Página {{ pagina() }} de {{ totalPaginas() }} ({{ total() }} usuarios)</span>
        <button type="button" [disabled]="pagina() >= totalPaginas()" (click)="irA(pagina() + 1)">Siguiente</button>
      </nav>
    }
  `,
})
export class UsuariosLista {
  private readonly servicio = inject(UsuariosService);

  protected readonly usuarios = signal<UsuarioLista[]>([]);
  protected readonly total = signal(0);
  protected readonly pagina = signal(1);
  protected readonly cargando = signal(false);
  protected readonly error = signal('');
  protected readonly totalPaginas = computed(() =>
    Math.max(1, Math.ceil(this.total() / TAMANO_PAGINA)),
  );

  private search = '';
  private activo?: boolean;

  constructor() {
    this.cargar();
  }

  protected buscar(evento: Event, texto: string, estado: string): void {
    evento.preventDefault();
    this.search = texto.trim();
    this.activo = estado === '' ? undefined : estado === 'true';
    this.pagina.set(1);
    this.cargar();
  }

  protected irA(pagina: number): void {
    this.pagina.set(pagina);
    this.cargar();
  }

  protected desactivar(u: UsuarioLista): void {
    if (!confirm(`¿Desactivar a ${u.nombre}? No podrá iniciar sesión.`)) {
      return;
    }
    this.error.set('');
    this.servicio.desactivar(u.id).subscribe({
      next: () => this.cargar(),
      error: (err) => this.error.set(mensajeError(err)),
    });
  }

  private cargar(): void {
    this.cargando.set(true);
    this.error.set('');
    this.servicio
      .listar({ page: this.pagina(), search: this.search, activo: this.activo })
      .subscribe({
        next: (r: Pagina<UsuarioLista>) => {
          this.usuarios.set(r.results);
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