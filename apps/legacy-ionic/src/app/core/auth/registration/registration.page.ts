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
import { RegionService } from '@app/core/service/region.service';

@Component({
  selector: 'app-registration',
  templateUrl: './registration.page.html',
  styleUrls: ['./registration.page.scss'],
})
export class RegistrationPage implements OnInit, OnDestroy {
  registerForm: UntypedFormGroup;

  isSubmitted = false;

  regions$ = this.regionService.getRegions();

  private destroy$ = new Subject();

  constructor(
    public authService: AuthenticationService,
    public regionService: RegionService,
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
    if (this.registerForm.invalid) {
      this.showAlert('Please fill all required fields correctly');
      return;
    }

    this.isSubmitted = true;
    const loading = await this.loadingController.create({
      message: 'Registering...',
    });

    try {
      await loading.present();

      const formData = this.registerForm.getRawValue();
      const payload = {
        ...formData,
        region: { id: formData.region },
      };

      await this.authService.registerUser(payload).toPromise();
      await this.navController.navigateRoot(['login']);
    } catch (error) {
      const errorMessage =
        error === 'Conflict'
          ? 'Username or email is already in use'
          : 'Registration failed. Please try again.';

      await this.showAlert(errorMessage);
    } finally {
      this.isSubmitted = false;
      await loading.dismiss();
    }
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
