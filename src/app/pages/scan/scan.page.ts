import { Component, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { BarcodeScanner } from '@ionic-native/barcode-scanner/ngx';
import { AlertController, NavController } from '@ionic/angular';
import { first } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import * as fn from '@app/shared/functions/functions-expression';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';

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

  emptyCode = false;

  editable = false;

  form: UntypedFormGroup;

  formBuilder = inject(UntypedFormBuilder);

  constructor(
    private barcodeScanner: BarcodeScanner,
    private navCtl: NavController,
    private alertController: AlertController,
    private router: Router,
    private fastingPersonService: FastingPersonService
  ) {}

  ngOnInit(): void {
    this.form = this.formBuilder.group({
      phone: ['', []],
      comment: ['', []],
    });
    this.openBarCodeScanner();
  }

  async openBarCodeScanner() {
    await this.barcodeScanner
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
          this.emptyCode = true;
          this.presentAlert();
        }
      })
      .catch((err) => {
        this.presentAlert();
      });
    this.loading = false;
    this.isSubmitted = false;
  }
  confirmAndOpenBarCodeScanner() {
    this.confirmMealTaken()
      .pipe(first())
      .subscribe({
        next: () => {
          this.form.reset();
          this.openBarCodeScanner();
        },
        error: (error) => {
          this.loading = false;
          this.isSubmitted = false;
        },
      });
  }

  stopScan() {
    this.navCtl.back();
  }

  getFastingPerson(id) {
    this.emptyCode = false;
    this.loading = true;
    this.isSubmitted = true;
    this.fastingPersonService
      .getFastingPersonById(id)
      .pipe(first())
      .subscribe({
        next: (person) => {
          this.loading = false;
          this.isSubmitted = false;

          this.fastingPerson = person?.data as FastingPerson;
          this.form.patchValue({
            ...this.fastingPerson,
          });
          if (Object.keys(person?.data || {}).length === 0) {
            this.emptyCode = true;
          } else {
            this.isMealTaken =
              fn.getDate(this.fastingPerson.lastTakenMeal) === fn.getDate();
          }
        },
        error: (error) => {
          this.emptyCode = true;
          this.isSubmitted = false;
          this.loading = false;
        },
      });
  }

  confirmMealTaken() {
    this.loading = true;
    this.isSubmitted = true;

    return this.fastingPersonService.confirmMeal({
      ...this.fastingPerson,
      ...this.form.getRawValue(),
    });
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
