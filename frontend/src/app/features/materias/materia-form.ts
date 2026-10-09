import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { MateriasService } from './materias.service';

@Component({
  selector: 'app-materia-form',
  imports: [ReactiveFormsModule, RouterLink],
  template: `
    <h2>{{ editando ? 'Editar materia' : 'Nueva materia' }}</h2>

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
          Descripción (opcional)
          <input type="text" formControlName="descripcion" autocomplete="off" />
        </label>
        @if (form.controls.descripcion.touched && form.controls.descripcion.invalid) {
          <small role="alert">La descripción admite máximo 255 caracteres.</small>
        }

        @if (error()) {
          <p role="alert">{{ error() }}</p>
        }

        <button type="submit" [disabled]="guardando()">
          {{ guardando() ? 'Guardando…' : 'Guardar' }}
        </button>
        <a routerLink="/materias">Cancelar</a>
      </form>
    }
  `,
})
export class MateriaForm {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly materias = inject(MateriasService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id')) || null;

  protected readonly editando = this.id !== null;
  protected readonly cargando = signal(false);
  protected readonly guardando = signal(false);
  protected readonly error = signal('');

  protected readonly form = this.fb.nonNullable.group({
    nombre: ['', [Validators.required, Validators.maxLength(150)]],
    descripcion: ['', [Validators.maxLength(255)]],
  });

  constructor() {
    if (this.id !== null) {
      this.cargando.set(true);
      this.materias.obtener(this.id).subscribe({
        next: (m) => {
          this.form.patchValue({ nombre: m.nombre, descripcion: m.descripcion });
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
    const datos = { nombre: v.nombre.trim(), descripcion: v.descripcion.trim() };

    this.guardando.set(true);
    this.error.set('');

    const peticion =
      this.id === null
        ? this.materias.crear(datos)
        : this.materias.actualizar(this.id, datos);

    peticion.subscribe({
      next: () => void this.router.navigate(['/materias']),
      error: (err) => {
        this.error.set(mensajeError(err));
        this.guardando.set(false);
      },
    });
  }
}