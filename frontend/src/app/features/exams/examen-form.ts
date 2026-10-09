import { Component, inject, signal } from '@angular/core';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Adjuntos } from '../adjuntos/adjuntos';
import { mensajeError } from '../../core/utils/api-error';
import { inputLocalAIso, isoAInputLocal } from '../../core/utils/fechas';
import { Materia, MateriasService } from '../materias/materias.service';
import { ExamenesService } from './examenes.service';

@Component({
  selector: 'app-examen-form',
  imports: [ReactiveFormsModule, RouterLink, Adjuntos],
  template: `
    <h2>{{ editando ? 'Editar examen' : 'Nuevo examen' }}</h2>

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

        <label>
          Fecha y hora de inicio
          <input type="datetime-local" formControlName="fecha_inicio" />
        </label>
        @if (form.controls.fecha_inicio.touched && form.controls.fecha_inicio.invalid) {
          <small role="alert">Indica la fecha de inicio.</small>
        }

        <label>
          Fecha y hora de fin
          <input type="datetime-local" formControlName="fecha_fin" />
        </label>
        @if (form.controls.fecha_fin.touched && form.controls.fecha_fin.invalid) {
          <small role="alert">Indica la fecha de fin.</small>
        }

        <label>
          Duración (minutos)
          <input type="number" formControlName="duracion_minutos" min="1" max="600" />
        </label>
        @if (form.controls.duracion_minutos.touched && form.controls.duracion_minutos.invalid) {
          <small role="alert">La duración debe estar entre 1 y 600 minutos.</small>
        }

        <label>
          Intentos permitidos
          <input type="number" formControlName="intentos_permitidos" min="1" max="10" />
        </label>
        @if (form.controls.intentos_permitidos.touched && form.controls.intentos_permitidos.invalid) {
          <small role="alert">Los intentos deben estar entre 1 y 10.</small>
        }

        @if (error()) {
          <p role="alert">{{ error() }}</p>
        }

        <button type="submit" [disabled]="guardando() || form.disabled">
          {{ guardando() ? 'Guardando…' : 'Guardar' }}
        </button>
        <a routerLink="/examenes">Cancelar</a>
      </form>
      @if (id !== null) {
        <app-adjuntos tipo="examen" [objetoId]="id" />
      }
    }
  `,
})
export class ExamenForm {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly examenes = inject(ExamenesService);
  private readonly materiasApi = inject(MateriasService);

  protected readonly id = Number(this.route.snapshot.paramMap.get('id')) || null;

  protected readonly editando = this.id !== null;
  protected readonly materias = signal<Materia[]>([]);
  protected readonly cargando = signal(false);
  protected readonly guardando = signal(false);
  protected readonly error = signal('');

  protected readonly form = this.fb.nonNullable.group({
    titulo: ['', [Validators.required, Validators.maxLength(200)]],
    descripcion: [''],
    materia: [null as number | null, [Validators.required]],
    fecha_inicio: ['', [Validators.required]],
    fecha_fin: ['', [Validators.required]],
    duracion_minutos: [60, [Validators.required, Validators.min(1), Validators.max(600)]],
    intentos_permitidos: [1, [Validators.required, Validators.min(1), Validators.max(10)]],
  });

  constructor() {
    this.materiasApi.listarTodas().subscribe({
      next: (m) => this.materias.set(m),
      error: (err) => this.error.set(mensajeError(err)),
    });

    if (this.id !== null) {
      this.cargando.set(true);
      this.examenes.obtener(this.id).subscribe({
        next: (e) => {
          this.form.patchValue({
            titulo: e.titulo,
            descripcion: e.descripcion,
            materia: e.materia,
            fecha_inicio: isoAInputLocal(e.fecha_inicio),
            fecha_fin: isoAInputLocal(e.fecha_fin),
            duracion_minutos: e.duracion_minutos,
            intentos_permitidos: e.intentos_permitidos,
          });
          if (e.estado !== 'borrador') {
            this.error.set('Solo se puede modificar un examen en borrador.');
            this.form.disable();
          }
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
    if (new Date(v.fecha_fin) <= new Date(v.fecha_inicio)) {
      this.error.set('La fecha de fin debe ser posterior a la de inicio.');
      return;
    }

    const datos = {
      materia: v.materia as number,
      titulo: v.titulo.trim(),
      descripcion: v.descripcion.trim(),
      fecha_inicio: inputLocalAIso(v.fecha_inicio),
      fecha_fin: inputLocalAIso(v.fecha_fin),
      duracion_minutos: v.duracion_minutos,
      intentos_permitidos: v.intentos_permitidos,
    };

    this.guardando.set(true);
    this.error.set('');

    const peticion =
      this.id === null ? this.examenes.crear(datos) : this.examenes.actualizar(this.id, datos);

    peticion.subscribe({
      next: () => void this.router.navigate(['/examenes']),
      error: (err) => {
        this.error.set(mensajeError(err));
        this.guardando.set(false);
      },
    });
  }
}