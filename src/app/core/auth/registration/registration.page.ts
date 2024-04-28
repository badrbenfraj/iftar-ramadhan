import { Component, OnDestroy, OnInit } from '@angular/core';
import {
  UntypedFormBuilder,
  UntypedFormGroup,
  Validators,
} from '@angular/forms';
import {
  AlertController,
  LoadingController,
  NavController,
} from '@ionic/angular';
import { Subject } from 'rxjs';
import { AuthenticationService } from '../authentication.service';
import { HttpStatusCode } from '@angular/common/http';

@Component({
  selector: 'app-registration',
  templateUrl: './registration.page.html',
  styleUrls: ['./registration.page.scss'],
})
export class RegistrationPage implements OnInit, OnDestroy {
  registerForm: UntypedFormGroup;

  isSubmitted = false;

  private destroy$ = new Subject();

  constructor(
    public authService: AuthenticationService,
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
    return this.registerForm.controls;
  }

  ngOnInit() {
    this.registerForm = this.formBuilder.group({
      name: ['', [Validators.required]],
      username: ['', [Validators.required]],
      region: ['', [Validators.required]],
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
      this.isSubmitted = false;
      await loading.dismiss();

      return;
    }
    this.authService.registerUser(this.registerForm.getRawValue()).subscribe({
      next: (res) => {
        // this.authService.sendVerificationMail();
        this.navController.navigateRoot(['login']);
        this.isSubmitted = false;
      },
      error: (error) => {
        this.isSubmitted = false;
        if (error === 'Conflict') {
          this.showAlert('Username or email is already in use');
        } else {
          this.showAlert(error);
        }
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
