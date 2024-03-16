import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';

import { Observable } from 'rxjs';
import { concatMap, map, shareReplay, tap } from 'rxjs/operators';
import { FastingPerson } from '../model/fasting-person.model';
import { environment } from '@env/environment';
import { AuthenticationService } from '../auth/authentication.service';

const BASE_PATH = environment.basePath;

@Injectable({
  providedIn: 'root',
})
export class FastingPersonService {
  authenticationService = inject(AuthenticationService);

  fastingPeople$: Observable<{ data: any[]; meta: any }>;

  constructor(private httpClient: HttpClient) {}

  getFastingPersons(
    limit = 1000,
    offset = 0
  ): Observable<{ data: any[]; meta: any }> {
    const params = {};
    const currentUser = this.authenticationService.currentUser;

    const isNumber = (value) => typeof value === 'number' && isFinite(value);

    if (limit > 0 && isNumber(limit)) {
      params['limit'] = limit;
    }

    if (isNumber(offset)) {
      params['offset'] = offset;
    }

    this.fastingPeople$ = this.httpClient
      .get<any>(`${BASE_PATH}/fastings/${currentUser?.region}`, { params })
      .pipe(
        map((items: any) => items?.data?.sort((a, b) => a.id - b.id)),
        shareReplay(1)
      );
    return this.fastingPeople$;
  }

  getFastingPersonById(id: string): Observable<any> {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/${currentUser?.region}/${id}`
    );
  }

  addFastingPerson(body: FastingPerson) {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient
      .post(`${BASE_PATH}/fastings/${currentUser?.region}`, body)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  deleteFastingPersonsList() {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient
      .delete<any>(`${BASE_PATH}/fastings/${currentUser?.region}/all`)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  deleteFastingPerson(fastingPerson: FastingPerson) {
    const currentUser = this.authenticationService.currentUser;
    return this.httpClient
      .delete<any>(
        `${BASE_PATH}/fastings/${currentUser?.region}/${fastingPerson?.id}`
      )
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  updateFastingPerson(body: FastingPerson) {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient
      .patch<any>(
        `${BASE_PATH}/fastings/${currentUser?.region}/${body?.id}`,
        body
      )
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  confirmMeal(body: FastingPerson) {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient
      .patch<any>(
        `${BASE_PATH}/fastings/confirm/${currentUser?.region}/${body?.id}`,
        body
      )
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  addBulkMeals(meals) {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/statistics/${currentUser?.region}`
    );
  }

  getDailyStatistics(): Observable<any> {
    const currentUser = this.authenticationService.currentUser;

    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/daily/statistics/${currentUser?.region}`
    );
  }
}
