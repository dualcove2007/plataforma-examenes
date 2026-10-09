import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import { Materia, MateriasService } from '../materias/materias.service';
import { BancosService } from './bancos.service';

@Component({
  selector: 'app-banco-form',
  imports: [ReactiveFormsModule, RouterLink],
  template: `
    <h2>{{ editando ? 'Editar banco' : 'Nuevo banco' }}</h2>

    @if (cargando()) {
      <p>Cargando…</p>
    } @else {
      <form [formGroup]="form" (ngSubmit)="guardar()" novalidate>
        <label>
          Título
          <input type="text" formControlName="titulo" autocomplete="off" />
        </label>
        @if (form.controls.titulo.touched && form.controls.titulo.invalid) {
          <small role="alert">Escribe un título (máximo 200 caracteres).</small>
        }

        <label>
          Descripción (opcional)
          <input type="text" formControlName="descripcion" autocomplete="off" />
        </label>
        @if (form.controls.descripcion.touched && form.controls.descripcion.invalid) {
          <small role="alert">La descripción admite máximo 255 caracteres.</small>
        }

        <label>
          Materia
          <select formControlName="materia">
            <option [ngValue]="null" disabled>Selecciona una materia</option>
            @for (m of materias(); track m.id) {
              <option [ngValue]="m.id">{{ m.nombre }}</option>
            }
          </select>
        </label>
        @if (form.controls.materia.touched && form.controls.materia.invalid) {
          <small role="alert">Selecciona una materia.</small>
        }
        @if (materiasCargadas() && materias().length === 0) {
          <small role="alert">
            No hay materias creadas. Pide al administrador que cree al menos una.
          </small>
        }

        @if (editando) {
          <label>
            <input type="checkbox" formControlName="activo" />
            Activo
          </label>
        }

        @if (error()) {
          <p role="alert">{{ error() }}</p>
        }

        <button type="submit" [disabled]="guardando()">
          {{ guardando() ? 'Guardando…' : 'Guardar' }}
        </button>
        <a routerLink="/bancos">Cancelar</a>
      </form>
    }
  `,
})
export class BancoForm {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly bancos = inject(BancosService);
  private readonly materiasApi = inject(MateriasService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id')) || null;

  protected readonly editando = this.id !== null;
  protected readonly materias = signal<Materia[]>([]);
  protected readonly materiasCargadas = signal(false);
  protected readonly cargando = signal(false);
  protected readonly guardando = signal(false);
  protected readonly error = signal('');

  protected readonly form = this.fb.nonNullable.group({
    titulo: ['', [Validators.required, Validators.maxLength(200)]],
    descripcion: ['', [Validators.maxLength(255)]],
    materia: [null as number | null, [Validators.required]],
    activo: [true],
  });

  constructor() {
    this.materiasApi.listarTodas().subscribe({
      next: (m) => {
        this.materias.set(m);
        this.materiasCargadas.set(true);
      },
      error: (err) => this.error.set(mensajeError(err)),
    });

    if (this.id !== null) {
      this.cargando.set(true);
      this.bancos.obtener(this.id).subscribe({
        next: (b) => {
          this.form.patchValue({
            titulo: b.titulo,
            descripcion: b.descripcion,
            materia: b.materia,
            activo: b.activo,
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
    const datos = {
      materia: v.materia as number,
      titulo: v.titulo.trim(),
      descripcion: v.descripcion.trim(),
      activo: v.activo,
    };

    this.guardando.set(true);
    this.error.set('');

    const peticion =
      this.id === null ? this.bancos.crear(datos) : this.bancos.actualizar(this.id, datos);

    peticion.subscribe({
      next: () => void this.router.navigate(['/bancos']),
      error: (err) => {
        this.error.set(mensajeError(err));
        this.guardando.set(false);
      },
    });
  }
}