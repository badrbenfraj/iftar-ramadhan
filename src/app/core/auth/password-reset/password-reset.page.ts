import { Component, OnInit } from '@angular/core';
import { NavController } from '@ionic/angular';
import { AuthenticationService } from '../authentication.service';

@Component({
  selector: 'app-password-reset',
  templateUrl: './password-reset.page.html',
  styleUrls: ['./password-reset.page.scss'],
})
export class PasswordResetPage implements OnInit {
  constructor(
    private navController: NavController,
    public authService: AuthenticationService) {}

  ngOnInit() {
    if (this.authService.isLoggedIn) {
      this.navController.navigateRoot(['/pages/list']);
    }
  }
}
