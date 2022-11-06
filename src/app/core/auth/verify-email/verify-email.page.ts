import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { NavController } from '@ionic/angular';
import { AuthenticationService } from '../authentication.service';

@Component({
  selector: 'app-verify-email',
  templateUrl: './verify-email.page.html',
  styleUrls: ['./verify-email.page.scss'],
})
export class VerifyEmailPage implements OnInit {
  constructor(
    private navController: NavController,
    public authService: AuthenticationService
  ) {}

  ngOnInit() {
    if (this.authService.isLoggedIn) {
      this.navController.navigateRoot(['/pages/list']);
    }
  }
}
