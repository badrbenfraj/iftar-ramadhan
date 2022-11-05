import { Injectable } from '@angular/core';
import { AngularFireDatabase } from '@angular/fire/compat/database';
import { AngularFirestore } from '@angular/fire/compat/firestore';

import { Observable } from 'rxjs';
import { filter, map, tap } from 'rxjs/operators';
import { FastingPerson } from '../model/fasting-person.model';

const COLLECTION_NAME = 'fasting-person';

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
      map((items) => items.filter((item) => item?.code === Number(code)))
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

  private async deleteItems(items) {
    items.forEach(async (item) => {
      await this.deleteFastingPerson(item);
    });
    this.updateFastingPersonCount(0);
  }
}
