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

  currentUser: {
    name: string;
    username: string;
    region: string;
    email: string;
    password: string;
  };

  constructor(private httpClient: HttpClient) {
    this.currentUser = this.authenticationService.currentUser;
  }

  getFastingPersons(
    limit = 1000,
    offset = 0
  ): Observable<{ data: any[]; meta: any }> {
    const params = {};

    const isNumber = (value) => typeof value === 'number' && isFinite(value);

    if (limit > 0 && isNumber(limit)) {
      params['limit'] = limit;
    }

    if (isNumber(offset)) {
      params['offset'] = offset;
    }

    this.fastingPeople$ = this.httpClient
      .get<any>(`${BASE_PATH}/fastings/${this.currentUser?.region}`, { params })
      .pipe(
        map((items: any) => items?.data?.sort((a, b) => a.id - b.id)),
        shareReplay(1)
      );
    return this.fastingPeople$;
  }

  getFastingPersonById(id: string): Observable<any> {
    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/${this.currentUser?.region}/${id}`
    );
  }

  addFastingPerson(body: FastingPerson) {
    return this.httpClient
      .post(`${BASE_PATH}/fastings/${this.currentUser?.region}`, body)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  deleteFastingPersonsList() {
    return this.httpClient
      .delete<any>(`${BASE_PATH}/fastings/${this.currentUser?.region}/all`)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  deleteFastingPerson(fastingPerson: FastingPerson) {
    return this.httpClient
      .delete<any>(
        `${BASE_PATH}/fastings/${this.currentUser?.region}/${fastingPerson?.id}`
      )
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  updateFastingPerson(body: FastingPerson) {
    return this.httpClient
      .patch<any>(
        `${BASE_PATH}/fastings/${this.currentUser?.region}/${body?.id}`,
        body
      )
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  addBulkMeals(meals) {
    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/bulk/${this.currentUser?.region}`
    );
  }

  getStatisticsByDate(creationDate: Date): Observable<any[]> {
    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/statistics/${this.currentUser?.region}/${creationDate}`
    );
  }
}
