import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

import { Observable } from 'rxjs';
import { concatMap, map, shareReplay, tap } from 'rxjs/operators';
import { FastingPerson } from '../model/fasting-person.model';
import { environment } from '@env/environment';

const BASE_PATH = environment.basePath;

@Injectable({
  providedIn: 'root',
})
export class FastingPersonService {
  fastingPeople$: Observable<{ data: any[]; meta: any }>;
  constructor(private httpClient: HttpClient) {}

  getFastingPersons(): Observable<{ data: any[]; meta: any }> {
    this.fastingPeople$ = this.httpClient
      .get<any>(`${BASE_PATH}/fastings`)
      .pipe(map((items: any) => items?.data?.sort((a, b) => a.id - b.id)), shareReplay(1));
    return this.fastingPeople$;
  }

  getFastingPersonById(id: string): Observable<any> {
    return this.httpClient.get<any>(`${BASE_PATH}/fastings/${id}`);
  }

  getFastingPersonsCount() {
    // return this.firestore
    //   .collection('ir-db-settings')
    //   .doc('LpZJuN6mvCNmlVKbiaBc')
    //   .valueChanges();
  }

  updateFastingPersonCount(count) {
    // return this.firestore
    //   .collection('ir-db-settings')
    //   .doc('LpZJuN6mvCNmlVKbiaBc')
    //   .update(count);
  }

  addFastingPerson(body: FastingPerson) {
    return this.httpClient
      .post(`${BASE_PATH}/fastings`, body)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  deleteFastingPersonsList() {
    return this.httpClient
      .delete<any>(`${BASE_PATH}/fastings/all`)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  deleteFastingPerson(fastingPerson: FastingPerson) {
    return this.httpClient
      .delete<any>(`${BASE_PATH}/fastings/${fastingPerson?.id}`)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  updateFastingPerson(body: FastingPerson) {
    return this.httpClient
      .patch<any>(`${BASE_PATH}/fastings/${body?.id}`, body)
      .pipe(concatMap(() => this.getFastingPersons()));
  }

  addBulkMeals(meals) {
    // return this.firestore.collection(COLLECTION_BULK_NAME).add(meals);
    // .pipe(concatMap(() => this.getFastingPersons()));
  }

  getStatisticsByDate(creationDate: Date): Observable<any[]> {
    return this.httpClient.get<any>(
      `${BASE_PATH}/fastings/statistics/${creationDate}`
    );
  }
}
