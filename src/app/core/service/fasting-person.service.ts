import { Injectable } from '@angular/core';
import { AngularFirestore } from '@angular/fire/compat/firestore';

import { Observable } from 'rxjs';
import { map, tap } from 'rxjs/operators';
import { FastingPerson } from '../model/fasting-person.model';

const COLLECTION_NAME = 'fasting-person';
const COLLECTION_BULK_NAME = 'bulk-meals';

@Injectable({
  providedIn: 'root',
})
export class FastingPersonService {
  constructor(private firestore: AngularFirestore) {}

  getFastingPersons(): Observable<any[]> {
    return this.firestore
      .collection(COLLECTION_NAME)
      .valueChanges({ idField: 'id' });
  }

  getFastingPersonById(code: string): Observable<any> {
    return this.getFastingPersons().pipe(
      map((items) =>
        items.filter((item) => Number(item?.code) === Number(code))
      )
    );
  }

  getFastingPersonsCount() {
    return this.firestore
      .collection('ir-db-settings')
      .doc('LpZJuN6mvCNmlVKbiaBc')
      .valueChanges();
  }

  updateFastingPersonCount(count) {
    return this.firestore
      .collection('ir-db-settings')
      .doc('LpZJuN6mvCNmlVKbiaBc')
      .update(count);
  }

  addFastingPerson(fastingPerson: FastingPerson) {
    return this.firestore.collection(COLLECTION_NAME).add(fastingPerson);
  }

  deleteFastingPersonsList() {
    return this.getFastingPersons().pipe(
      tap((items) => this.deleteItems(items))
    );
  }

  deleteFastingPerson(fastingPerson: FastingPerson) {
    return this.firestore
      .doc(COLLECTION_NAME + '/' + fastingPerson.id)
      .delete();
  }

  updateFastingPerson(fastingPerson: FastingPerson) {
    return this.firestore
      .collection(COLLECTION_NAME)
      .doc(fastingPerson.id)
      .update(fastingPerson);
  }

  addBulkMeals(meals) {
    return this.firestore.collection(COLLECTION_BULK_NAME).add(meals);
  }

  getStatisticsByDate(creationDate: Date): Observable<any[]> {
    return this.firestore
      .collection(COLLECTION_BULK_NAME, (ref) =>
        ref.where('creationDate', '==', creationDate)
      )
      .valueChanges({ idField: 'id' });
  }

  private async deleteItems(items) {
    items.forEach(async (item) => {
      await this.deleteFastingPerson(item);
    });
    this.updateFastingPersonCount(0);
  }
}
