import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { BarcodeScanner } from '@ionic-native/barcode-scanner/ngx';
import { AlertController, NavController } from '@ionic/angular';
import { first } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-scan',
  templateUrl: 'scan.page.html',
  styleUrls: ['scan.page.scss'],
})
export class ScanPage implements OnInit {
  fastingPerson;

  isSubmitted = false;

  isMealTaken = false;

  loading = false;

  constructor(
    private barcodeScanner: BarcodeScanner,
    private navCtl: NavController,
    private alertController: AlertController,
    private router: Router,
    private fastingPersonService: FastingPersonService
  ) {}

  ngOnInit(): void {
    this.openBarCodeScanner();
  }

  openBarCodeScanner() {
    this.loading = false;
    this.isSubmitted = false;
    this.barcodeScanner
      .scan({
        disableSuccessBeep: true,
        resultDisplayDuration: 0,
        formats: 'QR_CODE',
      })
      .then((barcodeData) => {
        this.loading = true;
        this.isSubmitted = true;
        if (barcodeData) {
          const scanCode = barcodeData.text;
          if (scanCode) {
            this.getFastingPerson(scanCode);
          }
        } else {
          this.presentAlert();
        }
      })
      .catch((err) => {
        this.presentAlert();
      });
  }
  confirmAndOpenBarCodeScanner() {
    if (this.isMealTaken) {
      this.openBarCodeScanner();
    } else {
      this.confirmMealTaken()
        .pipe(first())
        .subscribe({
          next: () => {
            this.openBarCodeScanner();
          },
          error: (error) => {
            this.loading = false;
            this.isSubmitted = false;
          },
        });
    }
  }

  stopScan() {
    this.navCtl.back();
  }

  getFastingPerson(id) {
    this.fastingPersonService
      .getFastingPersonById(id)
      .pipe(first())
      .subscribe({
        next: (person) => {
          this.loading = false;
          this.isSubmitted = false;

          this.fastingPerson = person?.data as FastingPerson;

          this.isMealTaken =
            new Date(this.fastingPerson.lastTakenMeal).setHours(0, 0, 0, 0) ===
            new Date().setHours(0, 0, 0, 0);
        },
        error: (error) => {
          this.isSubmitted = false;
          this.loading = false;
        },
      });
  }

  confirmMealTaken() {
    this.loading = true;
    this.isSubmitted = true;

    return this.fastingPersonService.confirmMeal(this.fastingPerson);
  }

  getTodayDate() {
    return new Date(new Date().setHours(0, 0, 0, 0)).toISOString();
  }

  async presentAlert() {
    this.loading = false;
    this.isSubmitted = false;

    const alert = await this.alertController.create({
      header: 'Warning',
      message: 'Please enter a valid qr code.',
      buttons: ['OK'],
    });
    await alert.present();
  }

  editPersonDetails(person) {
    this.router.navigate(['/pages/person/edit', person.id]);
  }
}
