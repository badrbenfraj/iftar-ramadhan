import { Component } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-pages',
  templateUrl: 'pages.page.html',
  styleUrls: ['pages.page.scss'],
})
export class PagesPage {
  constructor(private router: Router) {}

  goStartScan() {
    this.router.navigate(['/pages/scan']);
  }
}
