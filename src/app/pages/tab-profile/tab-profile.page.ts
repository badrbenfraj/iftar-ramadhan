import { Component } from '@angular/core';
import { User } from '@app/core/auth/model/user';
import { AuthenticationService } from 'src/app/core/auth/authentication.service';
import { saveAs } from 'file-saver';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import * as XLSX from 'xlsx';
import { Filesystem, Directory, Encoding } from '@capacitor/filesystem';

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
    return this.authenticationService.currentUser;
  }

  export() {
    this.fastingPersonService.getFastingPersons().subscribe((data) => {
      this.exportToExcel(data);
    });
  }

  logOut() {
    this.authenticationService.logout();
  }

  async exportToExcel(data) {
    const now = new Date();
    const time = `${now.getHours()}_${now.getMinutes()}`;
    const filename = `${now.toDateString()}-${time}.xlsx`;
    const ws: XLSX.WorkSheet = XLSX.utils.json_to_sheet(data);
    const wb: XLSX.WorkBook = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, filename);
    const excelBuffer: any = XLSX.write(wb, {
      bookType: 'xlsx',
      type: 'array',
    });
    try {
      const result = await Filesystem.writeFile({
        path: filename,
        data: excelBuffer,
        directory: Directory.Data,
        encoding: Encoding.UTF8,
        recursive: false,
      });
      console.log(result);
    } catch (e) {
      console.error(e);
    }
  }
}
