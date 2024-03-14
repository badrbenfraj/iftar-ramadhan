import { Component, OnDestroy, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { AuthenticationService } from '../authentication.service';
import {
  AlertController,
  LoadingController,
  NavController,
} from '@ionic/angular';
import {
  UntypedFormBuilder,
  UntypedFormGroup,
  Validators,
} from '@angular/forms';
import { Subject } from 'rxjs';
import { concatMap, takeUntil } from 'rxjs/operators';

@Component({
  selector: 'app-login',
  templateUrl: './login.page.html',
  styleUrls: ['./login.page.scss'],
})
export class LoginPage implements OnInit, OnDestroy {
  loginForm: UntypedFormGroup;

  isSubmitted = false;

  private destroy$ = new Subject();

  constructor(
    public authService: AuthenticationService,
    public router: Router,
    private navController: NavController,
    private alertController: AlertController,
    private loadingController: LoadingController,
    private formBuilder: UntypedFormBuilder
  ) {
    if (this.authService.isLoggedIn) {
      this.navController.navigateRoot(['/pages/list']);
    }
  }

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
      this.isSubmitted = false;

      return;
    }

    this.authService
      .signIn(this.form.email.value, this.form.password.value)
      .pipe(
        concatMap((token) => {
          const accessToken = token?.data?.accessToken;
          localStorage.setItem('token', JSON.stringify(accessToken));

          return this.authService.getCurrentUser();
        })
      )
      .subscribe({
        next: (user) => {
          if (user?.data) {
            localStorage.setItem('user', JSON.stringify(user?.data));
          } else {
            localStorage.setItem('user', null);
          }
          JSON.parse(localStorage.getItem('user'));

          if (!user?.data?.isAccountDisabled) {
            this.navController.navigateRoot(['pages']);
          } else {
            this.showAlert('Email is not verified');
            return false;
          }
          this.isSubmitted = false;
        },
        error: (error) => {
          this.isSubmitted = false;
          this.showAlert(error.message);
        },
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
