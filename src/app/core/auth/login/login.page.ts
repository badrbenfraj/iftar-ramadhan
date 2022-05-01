import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthenticationService } from '../authentication.service';
import { AlertController } from '@ionic/angular';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';

@Component({
  selector: 'app-login',
  templateUrl: './login.page.html',
  styleUrls: ['./login.page.scss'],
})
export class LoginPage implements OnInit {
  loginForm: FormGroup;
  isSubmitted = false;
  loading = false;

  constructor(
    public authService: AuthenticationService,
    public router: Router,
    private alertController: AlertController,
    private formBuilder: FormBuilder
  ) {}

  get form() {
    return this.loginForm.controls;
  }

  ngOnInit() {
    this.loginForm = this.formBuilder.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(3)]],
    });
  }

  onSubmit() {
    this.isSubmitted = true;

    // stop here if form is invalid
    if (this.loginForm.invalid) {
      return;
    }
    this.loading = true;
    this.authService
      .signIn(this.form.email.value, this.form.password.value)
      .then((res) => {
        this.loading = false;
        if (this.authService.isEmailVerified) {
          this.router.navigate(['tabs']);
        } else {
          this.presentAlert('Email is not verified');
          return false;
        }
      })
      .catch((error) => {
        this.loading = false;
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
