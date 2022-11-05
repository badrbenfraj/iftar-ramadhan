import { Component } from '@angular/core';
import { AuthenticationService } from 'src/app/core/auth/authentication.service';

@Component({
  selector: 'app-tab-profile',
  templateUrl: 'tab-profile.page.html',
  styleUrls: ['tab-profile.page.scss'],
})
export class TabProfilePage {
  constructor(private authenticationService: AuthenticationService) {}

  logOut() {
    this.authenticationService.signOut();
  }
}
