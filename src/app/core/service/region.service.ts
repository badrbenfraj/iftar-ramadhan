import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

import { Observable } from 'rxjs';
import { map, shareReplay } from 'rxjs/operators';
import { environment } from '@env/environment';
import { AuthenticationService } from '../auth/authentication.service';

const BASE_PATH = environment.basePath;

export interface Region {
  id: number;
  name: string;
}

@Injectable({
  providedIn: 'root',
})
export class RegionService {
  authenticationService = inject(AuthenticationService);

  constructor(private httpClient: HttpClient) {}

  getRegions(limit = 1000, offset = 0): Observable<Region[]> {
    const params = {};

    const isNumber = (value) => typeof value === 'number' && isFinite(value);

    if (limit > 0 && isNumber(limit)) {
      params['limit'] = limit;
    }

    if (isNumber(offset)) {
      params['offset'] = offset;
    }

    return this.httpClient.get<any>(`${BASE_PATH}/regions`, { params }).pipe(
      map((response) => response.data || []),
      shareReplay(1)
    );
  }
}
