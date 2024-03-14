import { Component } from '@angular/core';
import { User } from '@app/core/auth/model/user';
import { AuthenticationService } from 'src/app/core/auth/authentication.service';
import { saveAs } from 'file-saver';
import { first, map } from 'rxjs/operators';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import * as XLSX from 'xlsx';

@Component({
  selector: 'app-tab-profile',
  templateUrl: 'tab-profile.page.html',
  styleUrls: ['tab-profile.page.scss'],
})
export class TabProfilePage {
  constructor(
    private authenticationService: AuthenticationService,
    private fastingPersonService: FastingPersonService
  ) {}

  get loggedUser(): User {
    return this.authenticationService.loggedUser;
  }

  export() {
    this.fastingPersonService.fastingPeople$.subscribe((data) => {
      this.exportToExcel(data);
    });
  }

  logOut() {
    this.authenticationService.logout();
  }

  async exportToExcel(data) {
    const now = new Date();
    const time = `${now.getHours()}_${now.getMinutes()}`;
    const fileName = `${now.toDateString()}-${time}`;
    const ws: XLSX.WorkSheet = XLSX.utils.json_to_sheet(data);
    const wb: XLSX.WorkBook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, fileName);
    XLSX.writeFile(wb, `${fileName}.xlsx`);
  }
}
