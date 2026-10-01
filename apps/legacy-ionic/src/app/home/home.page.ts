import { Component, OnInit } from '@angular/core';
import { AuthenticationService } from '@app/core/auth/authentication.service';
import { NavController } from '@ionic/angular';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
})
export class HomePage implements OnInit {
  constructor(
    private navController: NavController,
    public authService: AuthenticationService
  ) {}
  ngOnInit(): void {
    if (this.authService.isLoggedIn) {
      this.navController.navigateRoot(['/pages/list']);
    }
  }
}
