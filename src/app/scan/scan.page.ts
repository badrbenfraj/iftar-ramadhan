import { AfterViewInit, Component, OnDestroy, OnInit } from '@angular/core';
import {
  SupportedFormat,
  BarcodeScanner,
} from '@capacitor-community/barcode-scanner';
import { AlertController, NavController } from '@ionic/angular';

@Component({
  selector: 'app-scan',
  templateUrl: 'scan.page.html',
  styleUrls: ['scan.page.scss'],
})
export class ScanPage implements OnInit, AfterViewInit, OnDestroy {
  result = null;
  scanActive = false;

  constructor(
    private alertController: AlertController,
    private navCtl: NavController
  ) {}

  ngOnInit(): void {
    this.startScan();
  }

  async startScan() {
    const allowed = await this.checkPermissions();
    if (allowed) {
      this.scanActive = true;
      const result = await BarcodeScanner.startScan({
        targetedFormats: [SupportedFormat.QR_CODE],
      });
      if (result.hasContent) {
        this.result = result.content;
        this.scanActive = false;
      }
    }
  }

  stopScan() {
    BarcodeScanner.stopScan();
    this.scanActive = false;
    this.navCtl.back();
  }

  async checkPermissions() {
    return new Promise(async (resolve, reject) => {
      const status = await BarcodeScanner.checkPermission({ force: true });
      if (status.granted) {
        resolve(true);
      } else if (status.denied) {
        const alert = this.alertController.create({
          header: 'No permission',
          message: '',
          buttons: [
            {
              text: 'No',
              role: 'Cancel',
            },
            {
              text: 'Open settings',
              handler: () => {
                BarcodeScanner.openAppSettings();
                resolve(false);
              },
            },
          ],
        });
        (await alert).present();
      } else {
        resolve(false);
      }
    });
  }

  ngAfterViewInit(): void {
    BarcodeScanner.prepare();
  }

  ngOnDestroy(): void {
    BarcodeScanner.stopScan();
  }
}
