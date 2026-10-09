import { Component, computed, inject, signal } from '@angular/core';
import { takeUntilDestroyed, toSignal } from '@angular/core/rxjs-interop';
import { FormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';

import { mensajeError } from '../../core/utils/api-error';
import {
  DIFICULTADES,
  Dificultad,
  PreguntaEscritura,
  PreguntasService,
  TIPOS,
  Tipo,
  TipoPregunta,
} from './preguntas.service';

@Component({
  selector: 'app-pregunta-form',
  imports: [ReactiveFormsModule, RouterLink],
  template: `
    <h2>{{ editando ? 'Editar pregunta' : 'Nueva pregunta' }}</h2>

    @if (cargando()) {
      <p>Cargando…</p>
    } @else {
      <form [formGroup]="form" (ngSubmit)="guardar()" novalidate>
        <label>
          Enunciado
          <textarea formControlName="enunciado" rows="4"></textarea>
        </label>
        @if (form.controls.enunciado.touched && form.controls.enunciado.invalid) {
          <small role="alert">Escribe el enunciado de la pregunta.</small>
        }

        <label>
          Tipo
          <select formControlName="tipo">
            @for (t of tipos; track t.valor) {
              <option [value]="t.valor">{{ t.etiqueta }}</option>
            }
          </select>
        </label>

        <label>
          Dificultad
          <select formControlName="dificultad">
            @for (d of dificultades; track d.valor) {
              <option [value]="d.valor">{{ d.etiqueta }}</option>
            }
          </select>
        </label>

        <label>
          Puntaje
          <input type="number" formControlName="puntaje" step="0.5" min="0.01" />
        </label>
        @if (form.controls.puntaje.touched && form.controls.puntaje.invalid) {
          <small role="alert">El puntaje debe ser mayor que 0.</small>
        }

        @if (editando) {
          <label>
            <input type="checkbox" formControlName="activo" />
            Activa
          </label>
        }

        @if (requiereOpciones()) {
          <fieldset>
            <legend>Opciones</legend>
            <small>{{ ayudaOpciones() }}</small>

            <div formArrayName="opciones">
              @for (op of opciones.controls; track $index; let i = $index) {
                <div [formGroupName]="i">
                  @if (esMultiple()) {
                    <input type="checkbox" formControlName="es_correcta" aria-label="Es correcta" />
                  } @else {
                    <input
                      type="radio"
                      name="correcta"
                      aria-label="Es correcta"
                      [checked]="op.controls.es_correcta.value"
                      (change)="marcarUnica(i)"
                    />
                  }
                  <input
                    type="text"
                    formControlName="texto"
                    placeholder="Texto de la opción"
                    [readOnly]="esVerdaderoFalso()"
                  />
                  @if (!esVerdaderoFalso()) {
                    <button
                      type="button"
                      [disabled]="opciones.length <= 2"
                      (click)="quitarOpcion(i)"
                    >
                      Quitar
                    </button>
                  }
                </div>
              }
            </div>

            @if (!esVerdaderoFalso()) {
              <button type="button" (click)="agregarOpcion()">Agregar opción</button>
            }
          </fieldset>
        }

        @if (error()) {
          <p role="alert">{{ error() }}</p>
        }

        <button type="submit" [disabled]="guardando()">
          {{ guardando() ? 'Guardando…' : 'Guardar' }}
        </button>
        <a [routerLink]="['/bancos', banco, 'preguntas']">Cancelar</a>
      </form>
    }
  `,
})
export class PreguntaForm {
  private readonly fb = inject(FormBuilder);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly preguntas = inject(PreguntasService);

  private readonly id = Number(this.route.snapshot.paramMap.get('id')) || null;

  /** Banco al que pertenece la pregunta (al editar se toma de la propia pregunta). */
  protected banco = Number(this.route.snapshot.paramMap.get('bancoId'));

  protected readonly editando = this.id !== null;
  protected readonly tipos = TIPOS;
  protected readonly dificultades = DIFICULTADES;
  protected readonly cargando = signal(false);
  protected readonly guardando = signal(false);
  protected readonly error = signal('');

  protected readonly opciones = this.fb.array([this.nuevaOpcion(), this.nuevaOpcion()]);

  protected readonly form = this.fb.nonNullable.group({
    enunciado: ['', [Validators.required]],
    tipo: [TipoPregunta.OpcionUnica as Tipo],
    dificultad: ['media' as Dificultad],
    puntaje: [1, [Validators.required, Validators.min(0.01)]],
    activo: [true],
    opciones: this.opciones,
  });

  protected readonly tipo = toSignal(this.form.controls.tipo.valueChanges, {
    initialValue: this.form.controls.tipo.value,
  });
  protected readonly requiereOpciones = computed(() => this.tipo() !== TipoPregunta.Abierta);
  protected readonly esVerdaderoFalso = computed(() => this.tipo() === TipoPregunta.VerdaderoFalso);
  protected readonly esMultiple = computed(() => this.tipo() === TipoPregunta.OpcionMultiple);
  protected readonly ayudaOpciones = computed(() => {
    switch (this.tipo()) {
      case TipoPregunta.VerdaderoFalso:
        return 'Marca cuál de las dos es la correcta.';
      case TipoPregunta.OpcionUnica:
        return 'Mínimo 2 opciones. Marca la única opción correcta.';
      default:
        return 'Mínimo 2 opciones. Marca una o más opciones correctas.';
    }
  });

  constructor() {
    // Al cambiar el tipo se reajustan las opciones (salvo mientras se carga una pregunta).
    this.form.controls.tipo.valueChanges.pipe(takeUntilDestroyed()).subscribe((t) => {
      if (!this.cargando()) {
        this.ajustarOpciones(t);
      }
    });

    if (this.id !== null) {
      this.cargando.set(true);
      this.preguntas.obtener(this.id).subscribe({
        next: (p) => {
          this.banco = p.banco;
          this.form.patchValue({
            enunciado: p.enunciado,
            tipo: p.tipo,
            dificultad: p.dificultad,
            puntaje: p.puntaje,
            activo: p.activo,
          });
          this.opciones.clear();
          p.opciones.forEach((o) => this.opciones.push(this.nuevaOpcion(o.texto, o.es_correcta)));
          this.cargando.set(false);
        },
        error: (err) => {
          this.error.set(mensajeError(err));
          this.cargando.set(false);
        },
      });
    }
  }

  protected marcarUnica(indice: number): void {
    this.opciones.controls.forEach((c, i) => c.controls.es_correcta.setValue(i === indice));
  }

  protected agregarOpcion(): void {
    this.opciones.push(this.nuevaOpcion());
  }

  protected quitarOpcion(indice: number): void {
    if (this.opciones.length > 2) {
      this.opciones.removeAt(indice);
    }
  }

  protected guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      this.error.set(
        this.opciones.invalid
          ? 'Completa el texto de todas las opciones.'
          : 'Revisa los campos marcados.',
      );
      return;
    }

    const mensaje = this.validarOpciones();
    if (mensaje) {
      this.error.set(mensaje);
      return;
    }

    const v = this.form.getRawValue();
    const datos: PreguntaEscritura = {
      banco: this.banco,
      enunciado: v.enunciado.trim(),
      tipo: v.tipo,
      dificultad: v.dificultad,
      puntaje: Number(v.puntaje),
      activo: v.activo,
      opciones:
        v.tipo === TipoPregunta.Abierta
          ? []
          : v.opciones.map((o) => ({ texto: o.texto.trim(), es_correcta: o.es_correcta })),
    };

    this.guardando.set(true);
    this.error.set('');

    const peticion =
      this.id === null ? this.preguntas.crear(datos) : this.preguntas.actualizar(this.id, datos);

    peticion.subscribe({
      next: () => void this.router.navigate(['/bancos', this.banco, 'preguntas']),
      error: (err) => {
        this.error.set(mensajeError(err));
        this.guardando.set(false);
      },
    });
  }

  // ------------------------------ internos ------------------------------
  private nuevaOpcion(texto = '', esCorrecta = false) {
    return this.fb.nonNullable.group({
      texto: [texto, [Validators.required, Validators.maxLength(500)]],
      es_correcta: [esCorrecta],
    });
  }

  private ajustarOpciones(tipo: Tipo): void {
    const arr = this.opciones;

    if (tipo === TipoPregunta.Abierta) {
      arr.clear();
      return;
    }

    if (tipo === TipoPregunta.VerdaderoFalso) {
      arr.clear();
      arr.push(this.nuevaOpcion('Verdadero', true));
      arr.push(this.nuevaOpcion('Falso', false));
      return;
    }

    while (arr.length < 2) {
      arr.push(this.nuevaOpcion());
    }

    if (tipo === TipoPregunta.OpcionUnica) {
      // Solo puede quedar una correcta: se conserva la primera marcada.
      const primera = arr.controls.findIndex((c) => c.controls.es_correcta.value);
      arr.controls.forEach((c, i) => c.controls.es_correcta.setValue(i === primera));
    }
  }

  private validarOpciones(): string | null {
    const tipo = this.form.controls.tipo.value;
    const opciones = this.opciones.getRawValue();
    const correctas = opciones.filter((o) => o.es_correcta).length;

    if (tipo === TipoPregunta.VerdaderoFalso && (opciones.length !== 2 || correctas !== 1)) {
      return 'Verdadero o falso lleva exactamente 2 opciones y 1 correcta.';
    }
    if (tipo === TipoPregunta.OpcionUnica && (opciones.length < 2 || correctas !== 1)) {
      return 'Opción única necesita al menos 2 opciones y exactamente 1 correcta.';
    }
    if (tipo === TipoPregunta.OpcionMultiple && (opciones.length < 2 || correctas < 1)) {
      return 'Opción múltiple necesita al menos 2 opciones y al menos 1 correcta.';
    }
    return null;
  }
}