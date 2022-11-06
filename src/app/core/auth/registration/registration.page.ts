import { Component, OnDestroy, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { AlertController, LoadingController } from '@ionic/angular';
import { Subject } from 'rxjs';
import { AuthenticationService } from '../authentication.service';

@Component({
  selector: 'app-registration',
  templateUrl: './registration.page.html',
  styleUrls: ['./registration.page.scss'],
})
export class RegistrationPage implements OnInit, OnDestroy {
  registerForm: FormGroup;

  isSubmitted = false;

  private destroy$ = new Subject();

  constructor(
    public authService: AuthenticationService,
    public router: Router,
    private alertController: AlertController,
    private loadingController: LoadingController,
    private formBuilder: FormBuilder
  ) {}

  get form() {
    return this.registerForm.controls;
  }

  ngOnInit() {
    this.registerForm = this.formBuilder.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(3)]],
    });
  }

  async onSubmit() {
    this.isSubmitted = true;
    const loading = await this.loadingController.create();
    await loading.present();

    // stop here if form is invalid
    if (this.registerForm.invalid) {
      await loading.dismiss();

      return;
    }
    this.authService
      .registerUser(this.form.email.value, this.form.password.value)
      .then((res) => {
        // Do something here
        this.authService.sendVerificationMail();
      })
      .catch((error) => {
        this.showAlert(error.message);
      });
    await loading.dismiss();
  }

  async showAlert(message) {
    const alert = await this.alertController.create({
      header: 'Warning',
      message,
      buttons: ['OK'],
    });
    await alert.present();
  }

  ngOnDestroy(): void {
    this.destroy$.next(true);
    this.destroy$.complete();
  }
}
