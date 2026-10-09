import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';

import { environment } from '../../../environments/environment';
import { NombreRol } from '../../core/models/auth.models';
import { Pagina } from '../../core/models/pagina';

export interface UsuarioLista {
  id: number;
  nombre: string;
  email: string;
  rol: number;
  rol_nombre: NombreRol;
  activo: boolean;
  fecha_creacion: string;
}

export interface FiltrosUsuarios {
  page: number;
  search?: string;
  activo?: boolean;
}

@Injectable({ providedIn: 'root' })
export class UsuariosService {
  private readonly http = inject(HttpClient);
  private readonly url = `${environment.apiUrl}/usuarios/`;

  listar(f: FiltrosUsuarios): Observable<Pagina<UsuarioLista>> {
    let params = new HttpParams().set('page', f.page);
    if (f.search) params = params.set('search', f.search);
    if (f.activo !== undefined) params = params.set('activo', f.activo);
    return this.http.get<Pagina<UsuarioLista>>(this.url, { params });
  }
}