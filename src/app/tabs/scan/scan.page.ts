import { Component, OnInit } from '@angular/core';
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
  fastingPerson: FastingPerson;

  constructor(
    private barcodeScanner: BarcodeScanner,
    private navCtl: NavController,
    private alertController: AlertController,
    private fastingPersonService: FastingPersonService
  ) {}

  ngOnInit(): void {
    this.openBarCodeScanner();
  }

  openBarCodeScanner() {
    this.barcodeScanner
      .scan({
        disableSuccessBeep: true,
        resultDisplayDuration: 0,
        formats: 'QR_CODE',
      })
      .then((barcodeData) => {
        //   Barcode data {"cancelled":0,"text":"8413384010008","format":"EAN_13"}
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

  stopScan() {
    this.navCtl.back();
  }

  async getFastingPerson(id) {
    this.fastingPersonService
      .getFastingPersonById(id)
      .pipe(first())
      .subscribe((person: FastingPerson) => (this.fastingPerson = person));
  }

  async presentAlert() {
    const alert = await this.alertController.create({
      header: 'Warning',
      message: 'Please enter a valid qr code.',
      buttons: ['OK'],
    });
    await alert.present();
  }
}
