import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AlertController } from '@ionic/angular';
import { AuthenticationService } from '../authentication.service';

@Component({
  selector: 'app-registration',
  templateUrl: './registration.page.html',
  styleUrls: ['./registration.page.scss'],
})
export class RegistrationPage implements OnInit {
  constructor(
    public authService: AuthenticationService,
    public router: Router,
    private alertController: AlertController
  ) {}

  ngOnInit() {}

  signUp(email, password) {
    this.authService
      .registerUser(email.value, password.value)
      .then((res) => {
        // Do something here
        this.authService.sendVerificationMail();
      })
      .catch((error) => {
        this.presentAlert(error.message);
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
