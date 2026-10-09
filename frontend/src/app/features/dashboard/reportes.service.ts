import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';

export interface ExamenResumen {
  id: number;
  titulo: string;
  estado: string;
  asignados: number;
  presentaron: number;
  revisados: number;
  promedio_nota: number | null;
  aprobados: number;
  reprobados: number;
}

export interface Estadisticas {
  nota_minima: number | string;
  examenes: Record<string, number>;
  asignaciones: number;
  intentos: Record<string, number>;
  resultados: {
    total: number;
    revisados: number;
    pendientes_revision: number;
    promedio_nota: number | null;
    aprobados: number;
    reprobados: number;
    tasa_aprobacion: number | null;
  };
  por_examen: ExamenResumen[];
}

@Injectable({ providedIn: 'root' })
export class ReportesService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/reportes`;

  estadisticas(): Observable<Estadisticas> {
    return this.http.get<Estadisticas>(`${this.url}/estadisticas/`);
  }

  descargarNotas(examenId: number): Observable<Blob> {
    return this.http.get(`${this.url}/notas/`, {
      params: { examen: examenId },
      responseType: 'blob',
    });
  }
}