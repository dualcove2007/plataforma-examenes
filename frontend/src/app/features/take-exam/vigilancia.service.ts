import { DOCUMENT } from '@angular/common';
import { Injectable, inject } from '@angular/core';
import { catchError, of } from 'rxjs';

import { IntentosService } from './intentos.service';

/**
 * Anti-trampa básico: mientras el estudiante rinde, avisa al backend cuando
 * sale de la pestaña (y cuánto tiempo estuvo fuera) o cuando pega texto.
 *
 * Son señales para el docente, no pruebas. Los fallos de red se ignoran a
 * propósito: nunca deben estorbar al estudiante mientras responde.
 */
@Injectable()
export class VigilanciaIntento {
  private readonly api = inject(IntentosService);
  private readonly doc = inject(DOCUMENT);

  private intentoId: number | null = null;
  private ocultoDesde: number | null = null;

  private readonly alCambiarVisibilidad = () => {
    if (this.intentoId === null) return;
    if (this.doc.visibilityState === 'hidden') {
      this.ocultoDesde ??= Date.now();
      return;
    }
    if (this.ocultoDesde === null) return;
    const segundos = Math.round((Date.now() - this.ocultoDesde) / 1000);
    this.ocultoDesde = null;
    // Parpadeos de menos de 1 segundo no son una salida real.
    if (segundos >= 1) this.enviar('salida_pestana', segundos);
  };

  private readonly alPegar = () => {
    if (this.intentoId !== null) this.enviar('pegado');
  };

  iniciar(intentoId: number): void {
    this.detener();
    this.intentoId = intentoId;
    this.doc.addEventListener('visibilitychange', this.alCambiarVisibilidad);
    this.doc.addEventListener('paste', this.alPegar);
  }

  detener(): void {
    this.doc.removeEventListener('visibilitychange', this.alCambiarVisibilidad);
    this.doc.removeEventListener('paste', this.alPegar);
    this.intentoId = null;
    this.ocultoDesde = null;
  }

  private enviar(tipo: 'salida_pestana' | 'pegado', segundos?: number): void {
    if (this.intentoId === null) return;
    this.api
      .registrarEvento(this.intentoId, tipo, segundos)
      .pipe(catchError(() => of(null)))
      .subscribe();
  }
}