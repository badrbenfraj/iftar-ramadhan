import { Component, OnInit } from '@angular/core';
import { Http } from '@capacitor-community/http';
import { BarcodeScanner } from '@ionic-native/barcode-scanner/ngx';
import { AlertController, NavController } from '@ionic/angular';
import { environment } from 'src/environments/environment';

const BASE_PATH = environment.basePath;

@Component({
  selector: 'app-scan',
  templateUrl: 'scan.page.html',
  styleUrls: ['scan.page.scss'],
})
export class ScanPage implements OnInit {
  data = null;

  constructor(
    private barcodeScanner: BarcodeScanner,
    private navCtl: NavController,
    private alertController: AlertController
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
            this.getProductWithBarCode(scanCode);
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

  async getProductWithBarCode(barcode) {
    const url = BASE_PATH + barcode + '.json';
    const result = await Http.request({
      method: 'GET',
      url,
      headers: {
        'content-type': 'application/json',
      },
    });
    if (result.data) {
      this.data = result.data;
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
}
