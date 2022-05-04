import { Injectable } from '@angular/core';
import { AngularFirestore } from '@angular/fire/compat/firestore';

import { Observable } from 'rxjs';
import { FastingPerson } from '../model/fasting-person.model';

const COLLECTION_NAME = 'fasting-person';

@Injectable({
  providedIn: 'root',
})
export class FastingPersonService {
  constructor(private ngFirestore: AngularFirestore) {}

  getFastingPersons(): Observable<any> {
    // const fastingPersonsRef = collection(this.firestore, 'fasting-person');
    // return collectionData(fastingPersonsRef, { idField: 'id' }) as Observable<
    //   FastingPerson[]
    // >;
    return this.ngFirestore
      .collection(COLLECTION_NAME)
      .valueChanges({ idField: 'id' });
  }

  getFastingPersonById(id) {
    // const fastingPersonDocRef = doc(this.firestore, `fasting-person/${id}`);
    // return docData(fastingPersonDocRef, {
    //   idField: 'id',
    // }) as Observable<FastingPerson>;
    return this.ngFirestore.collection(COLLECTION_NAME).doc(id).valueChanges();
  }

  addFastingPerson(fastingPerson: FastingPerson) {
    // const fastingPersonsRef = collection(this.firestore, 'fasting-person');
    // return addDoc(fastingPersonsRef, fastingPerson);

    return this.ngFirestore.collection(COLLECTION_NAME).add(fastingPerson);
  }

  deleteFastingPerson(fastingPerson: FastingPerson) {
    // const fastingPersonDocRef = doc(
    //   this.firestore,
    //   `fasting-person/${fastingPerson.id}`
    // );
    // return deleteDoc(fastingPersonDocRef);
    return this.ngFirestore
      .doc(COLLECTION_NAME + '/' + fastingPerson.id)
      .delete();
  }

  updateFastingPerson(fastingPerson: FastingPerson) {
    // const fastingPersonDocRef = doc(
    //   this.firestore,
    //   `fasting-person/${fastingPerson.id}`
    // );
    // const { firstName, lastName, fasting } = fastingPerson;
    // return updateDoc(fastingPersonDocRef, { firstName, lastName, fasting });
    return this.ngFirestore
      .collection(COLLECTION_NAME)
      .doc(fastingPerson.id)
      .update(fastingPerson);
  }
}
