import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { NombreRol } from '../../core/models/auth.models';

export interface RolItem {
  id: number;
  nombre: NombreRol;
  descripcion: string;
  permisos: number[];
}

@Injectable({ providedIn: 'root' })
export class RolesService {
  private readonly http = inject(HttpClient);

  listar(): Observable<RolItem[]> {
    return this.http.get<RolItem[]>(`${environment.apiUrl}/roles/`);
  }
}