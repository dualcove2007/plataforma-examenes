import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { RolItem, RolesService } from './roles.service';
import { UsuarioEscritura, UsuariosService } from './usuarios.service';

@Component({
  selector: 'app-usuario-form',
  imports: [ReactiveFormsModule, RouterLink],
  template: `
    <h2>{{ editando ? 'Editar usuario' : 'Nuevo usuario' }}</h2>

    @if (cargando()) {
      <p>Cargando…</p>
    } @else {
      <form [formGroup]="form" (ngSubmit)="guardar()" novalidate>
        <label>
          Nombre
          <input type="text" formControlName="nombre" autocomplete="off" />
        </label>
        @if (form.controls.nombre.touched && form.controls.nombre.invalid) {
          <small role="alert">Escribe un nombre (máximo 150 caracteres).</small>
        }

        <label>
          Correo
          <input type="email" formControlName="email" autocomplete="off" />
        </label>
        @if (form.controls.email.touched && form.controls.email.invalid) {
          <small role="alert">Escribe un correo válido.</small>
        }

        <label>
          Contraseña
          @if (editando) {
            <small>(opcional: déjala vacía para no cambiarla)</small>
          }
          <input type="password" formControlName="password" autocomplete="new-password" />
        </label>
        @if (form.controls.password.touched && form.controls.password.invalid) {
          <small role="alert">La contraseña es obligatoria.</small>
        }

        <label>
          Rol
          <select formControlName="rol">
            <option [ngValue]="null" disabled>Selecciona un rol</option>
            @for (r of roles(); track r.id) {
              <option [ngValue]="r.id">{{ r.nombre }}</option>
            }
          </select>
        </label>
        @if (form.controls.rol.touched && form.controls.rol.invalid) {
          <small role="alert">Selecciona un rol.</small>
        }

        <label>
          <input type="checkbox" formControlName="activo" />
          Activo
        </label>

        @if (error()) {
          <p role="alert">{{ error() }}</p>
        }

        <button type="submit" [disabled]="guardando()">
          {{ guardando() ? 'Guardando…' : 'Guardar' }}
        </button>
        <a routerLink="/usuarios">Cancelar</a>
      </form>
    }
  `,
})
export class UsuarioForm {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly usuarios = inject(UsuariosService);
  private readonly rolesApi = inject(RolesService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id')) || null;

  protected readonly editando = this.id !== null;
  protected readonly roles = signal<RolItem[]>([]);
  protected readonly cargando = signal(false);
  protected readonly guardando = signal(false);
  protected readonly error = signal('');

  protected readonly form = this.fb.nonNullable.group({
    nombre: ['', [Validators.required, Validators.maxLength(150)]],
    email: ['', [Validators.required, Validators.email]],
    password: [''],
    rol: [null as number | null, [Validators.required]],
    activo: [true],
  });

  constructor() {
    // Al crear, la contraseña es obligatoria; al editar, es opcional.
    if (!this.editando) {
      this.form.controls.password.addValidators(Validators.required);
    }

    this.rolesApi.listar().subscribe({
      next: (r) => this.roles.set(r),
      error: (err) => this.error.set(mensajeError(err)),
    });

    if (this.id !== null) {
      this.cargando.set(true);
      this.usuarios.obtener(this.id).subscribe({
        next: (u) => {
          this.form.patchValue({
            nombre: u.nombre,
            email: u.email,
            rol: u.rol,
            activo: u.activo,
          });
          this.cargando.set(false);
        },
        error: (err) => {
          this.error.set(mensajeError(err));
          this.cargando.set(false);
        },
      });
    }
  }

  protected guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const v = this.form.getRawValue();
    const datos: UsuarioEscritura = {
      nombre: v.nombre.trim(),
      email: v.email.trim(),
      rol: v.rol as number,
      activo: v.activo,
    };
    if (v.password) {
      datos.password = v.password;
    }

    this.guardando.set(true);
    this.error.set('');

    const peticion =
      this.id === null ? this.usuarios.crear(datos) : this.usuarios.actualizar(this.id, datos);

    peticion.subscribe({
      next: () => void this.router.navigate(['/usuarios']),
      error: (err) => {
        this.error.set(mensajeError(err));
        this.guardando.set(false);
      },
    });
  }
}