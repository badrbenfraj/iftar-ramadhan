import { Component } from '@angular/core';
import { User } from '@app/core/auth/model/user';
import { AuthenticationService } from 'src/app/core/auth/authentication.service';

@Component({
  selector: 'app-tab-profile',
  templateUrl: 'tab-profile.page.html',
  styleUrls: ['tab-profile.page.scss'],
})
export class TabProfilePage {
  constructor(private authenticationService: AuthenticationService) {}

  get loggedUser(): User {
    return this.authenticationService.loggedUser;
  }

  logOut() {
    this.authenticationService.signOut();
  }
}
