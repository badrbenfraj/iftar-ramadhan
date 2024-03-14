import { Injectable, NgZone, inject } from '@angular/core';
import { Router } from '@angular/router';
import { AlertController, NavController } from '@ionic/angular';
import { HttpClient } from '@angular/common/http';
import { environment } from '@env/environment';

const BASE_PATH = environment.basePath;

@Injectable({
  providedIn: 'root',
})
export class AuthenticationService {
  httpClient = inject(HttpClient);

  userData: any;

  constructor(
    private navController: NavController,
    public router: Router,
    public ngZone: NgZone,
    private alertController: AlertController
  ) {}

  // Returns true when user is looged in
  get isLoggedIn(): boolean {
    const user = JSON.parse(localStorage.getItem('user'));
    return user !== null && user.isAccountDisabled === false;
  }
  // Returns true when user's email is verified
  get isEmailVerified(): boolean {
    const user = JSON.parse(localStorage.getItem('user'));
    return !user.isAccountDisabled;
  }

  get loggedUser() {
    return {
      token: JSON.parse(localStorage.getItem('token')),
      ...JSON.parse(localStorage.getItem('user')),
    };
  }

  getAuthState() {
  }

  getCurrentUser() {
    return this.httpClient.get<any>(`${BASE_PATH}/users/me`);
  }

  // Login in with email/password
  signIn(email, password) {
    const body = {
      username: 'e2etester',
      password,
      email,
    };
    return this.httpClient.post<any>(`${BASE_PATH}/auth/login`, body);
  }

  registerUser(
    name: string,
    username: string,
    email: string,
    password: string
  ) {
    const body = {
      name,
      username,
      password,
      email,
    };
    return this.httpClient.post<any>(`${BASE_PATH}/auth/register`, body);
  }

  // Sign-out
  logout() {
    // remove user from local storage to log user out
    localStorage.removeItem('user');
    localStorage.removeItem('token');
    this.navController.navigateRoot(['/']);
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
