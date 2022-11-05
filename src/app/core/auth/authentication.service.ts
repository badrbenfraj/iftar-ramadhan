import { Injectable, NgZone } from '@angular/core';
import * as auth from 'firebase/auth';
import { User } from './model/user';
import { Router } from '@angular/router';
import { AngularFireAuth } from '@angular/fire/compat/auth';
import { AlertController } from '@ionic/angular';
import {
  AngularFirestore,
  AngularFirestoreDocument,
} from '@angular/fire/compat/firestore';

@Injectable({
  providedIn: 'root',
})
export class AuthenticationService {
  userData: any;
  constructor(
    public afStore: AngularFirestore,
    public ngFireAuth: AngularFireAuth,
    public router: Router,
    public ngZone: NgZone,
    private alertController: AlertController
  ) {}

  // Returns true when user is looged in
  get isLoggedIn(): boolean {
    const user = JSON.parse(localStorage.getItem('user'));
    return user !== null && user.emailVerified !== false ? true : false;
  }
  // Returns true when user's email is verified
  get isEmailVerified(): boolean {
    const user = JSON.parse(localStorage.getItem('user'));
    return user.emailVerified;
  }

  getAuthState() {
    return this.ngFireAuth.authState;
  }

  // Login in with email/password
  signIn(email, password) {
    return this.ngFireAuth.signInWithEmailAndPassword(email, password);
  }
  // Register user with email/password
  registerUser(email, password) {
    return this.ngFireAuth.createUserWithEmailAndPassword(email, password);
  }
  // Email verification when new user register
  sendVerificationMail() {
    return this.ngFireAuth.currentUser.then((user) =>
      user.sendEmailVerification().then(() => {
        this.router.navigate(['login']);
      })
    );
  }
  // Recover password
  passwordRecover(passwordResetEmail) {
    return this.ngFireAuth
      .sendPasswordResetEmail(passwordResetEmail)
      .then(() => {
        this.presentAlert(
          'Password reset email has been sent, please check your inbox.'
        );
      })
      .catch((error) => {
        this.presentAlert(error);
      });
  }

  // Sign in with Gmail
  googleAuth() {
    return this.authLogin(new auth.GoogleAuthProvider());
  }
  // Auth providers
  authLogin(provider) {
    return this.ngFireAuth
      .signInWithPopup(provider)
      .then((result) => {
        this.ngZone.run(() => {
          this.router.navigate(['tabs']);
        });
        this.setUserData(result.user);
      })
      .catch((error) => {
        this.presentAlert(error);
      });
  }
  // Store user in localStorage
  setUserData(user) {
    const userRef: AngularFirestoreDocument<any> = this.afStore.doc(
      `users/${user.uid}`
    );
    const userData: User = {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      emailVerified: user.emailVerified,
    };
    return userRef.set(userData, {
      merge: true,
    });
  }
  // Sign-out
  signOut() {
    return this.ngFireAuth.signOut().then(() => {
      localStorage.removeItem('user');
      this.router.navigate(['login']);
    });
  }

  async presentAlert(message) {
    const alert = await this.alertController.create({
      header: 'Warning',
      message,
      buttons: ['OK'],
    });
    await alert.present();
  }
}
