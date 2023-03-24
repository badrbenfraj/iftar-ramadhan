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
  isMealTaken = false;

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

  openBarCodeScanner(confirm?) {
    this.barcodeScanner
      .scan({
        disableSuccessBeep: true,
        resultDisplayDuration: 0,
        formats: 'QR_CODE',
      })
      .then((barcodeData) => {
        // Barcode data {"cancelled":0,"text":"8413384010008","format":"EAN_13"}
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
    this.confirmMealTaken().then(() => {
      this.barcodeScanner
        .scan({
          disableSuccessBeep: true,
          resultDisplayDuration: 0,
          formats: 'QR_CODE',
        })
        .then((barcodeData) => {
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
    });
  }

  stopScan() {
    this.navCtl.back();
  }

  async getFastingPerson(code) {
    this.fastingPersonService
      .getFastingPersonById(code)
      .pipe(first())
      .subscribe((person) => {
        this.fastingPerson = person.length
          ? (person[0] as FastingPerson)
          : undefined;
        this.isMealTaken =
          new Date(this.fastingPerson.lastTakenMeal).setHours(0, 0, 0, 0) ===
          new Date().setHours(0, 0, 0, 0);
      });
  }

  async confirmMealTaken() {
    if (this.fastingPerson) {
      this.fastingPerson.lastTakenMeal = new Date().toISOString();
      return await this.fastingPersonService.updateFastingPerson(
        this.fastingPerson
      );
    }
  }

  async presentAlert() {
    const alert = await this.alertController.create({
      header: 'Warning',
      message: 'Please enter a valid qr code.',
      buttons: ['OK'],
    });
    await alert.present();
  }

  editPersonDetails(person) {
    this.router.navigate(['/pages/person/edit', person.code]);
  }
}
