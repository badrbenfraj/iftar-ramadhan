import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthenticationService } from '../authentication.service';
import { AlertController, LoadingController } from '@ionic/angular';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';

@Component({
  selector: 'app-login',
  templateUrl: './login.page.html',
  styleUrls: ['./login.page.scss'],
})
export class LoginPage implements OnInit, OnDestroy {
  loginForm: FormGroup;

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
    return this.loginForm.controls;
  }

  ngOnInit() {
    this.loginForm = this.formBuilder.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(3)]],
    });
  }

  async onSubmit() {
    this.isSubmitted = true;
    const loading = await this.loadingController.create();
    await loading.present();

    // stop here if form is invalid
    if (this.loginForm.invalid) {
      await loading.dismiss();

      return;
    }

    this.authService
      .signIn(this.form.email.value, this.form.password.value)
      .then((res) => {
        this.authService
          .getAuthState()
          .pipe(takeUntil(this.destroy$))
          .subscribe((user) => {
            if (user) {
              localStorage.setItem('user', JSON.stringify(user));
              JSON.parse(localStorage.getItem('user'));
            } else {
              localStorage.setItem('user', null);
              JSON.parse(localStorage.getItem('user'));
            }

            if (this.authService.isEmailVerified) {
              this.router.navigate(['tabs']);
            } else {
              this.showAlert('Email is not verified');
              return false;
            }
            this.isSubmitted = false;
          });
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
