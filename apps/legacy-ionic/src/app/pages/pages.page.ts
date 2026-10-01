import { Component, ElementRef } from '@angular/core';
import { Router } from '@angular/router';
import { Platform } from '@ionic/angular';

@Component({
  selector: 'app-pages',
  templateUrl: 'pages.page.html',
  styleUrls: ['pages.page.scss'],
})
export class PagesPage {
  constructor(
    private router: Router,
    private platform: Platform,
    private elementRef: ElementRef
  ) {
    this.setupKeyboardListeners();
  }

  private setupKeyboardListeners() {
    this.platform.ready().then(() => {
      window.addEventListener('keyboardWillShow', () => {
        this.elementRef.nativeElement.querySelector('ion-tabs').classList.add('keyboard-is-visible');
      });

      window.addEventListener('keyboardWillHide', () => {
        this.elementRef.nativeElement.querySelector('ion-tabs').classList.remove('keyboard-is-visible');
      });
    });
  }

  goStartScan() {
    this.router.navigate(['/pages/scan']);
  }
}
