import { Component, OnInit } from '@angular/core';
import {
  UntypedFormBuilder,
  UntypedFormGroup,
  Validators,
} from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AlertController } from '@ionic/angular';
import { first } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import * as fn from '@app/shared/functions/functions-expression';

@Component({
  selector: 'app-edit-person-details',
  templateUrl: 'edit-person-details.page.html',
  styleUrls: ['edit-person-details.page.scss'],
})
export class EditPersonDetailsPage implements OnInit {
  fastingPerson: FastingPerson;

  fastingPersonForm: UntypedFormGroup;

  isSubmitted: boolean;

  constructor(
    private activeRoute: ActivatedRoute,
    private router: Router,
    private formBuilder: UntypedFormBuilder,
    private alertController: AlertController,
    private fastingPersonService: FastingPersonService
  ) {}

  get form() {
    return this.fastingPersonForm.controls;
  }

  ngOnInit(): void {
    this.fastingPersonForm = this.formBuilder.group({
      id: [null, []],
      firstName: ['', [Validators.required]],
      lastName: ['', [Validators.required]],
      familyMeal: [null, [Validators.required]],
      singleMeal: [null, [Validators.required]],
      region: [null, [Validators.required]],
      phone: ['', []],
      comment: ['', []],
    });
    this.getFastingPerson();
  }

  refreshFastingPeople(event) {
    this.getFastingPerson().then(() => {
      event.target.complete();
    });
  }

  async getFastingPerson() {
    this.activeRoute.params.pipe(first()).subscribe((params) => {
      this.fastingPersonService
        .getFastingPersonById(params.code)
        .pipe(first())
        .subscribe((person) => {
          this.fastingPerson = person?.data as FastingPerson;

          if (this.fastingPerson) {
            this.fastingPersonForm.patchValue({
              ...this.fastingPerson,
            });
          }
        });
    });
  }
  onSubmit() {
    this.isSubmitted = true;
    if (this.form.singleMeal?.value === 0) {
      this.form.singleMeal.setErrors({ incorrect: true });
    }

    if (this.form.familyMeal?.value === 0) {
      this.form.familyMeal.setErrors({ incorrect: true });
    }

    if (this.form.singleMeal?.value > 0 && !this.form.familyMeal?.value) {
      this.form.familyMeal.patchValue(0);
    }

    if (this.form.familyMeal?.value > 0 && !this.form.singleMeal?.value) {
      this.form.singleMeal.patchValue(0);
    }

    if (this.fastingPersonForm.invalid) {
      this.isSubmitted = false;

      return;
    }

    this.fastingPersonService
      .updateFastingPerson(this.fastingPersonForm.getRawValue())
      .subscribe({
        next: () => {
          this.isSubmitted = false;
          this.fastingPersonForm.reset();
          this.fastingPersonService.getFastingPersons();
          this.router.navigate(['pages']);
        },
        error: (error) => {
          this.isSubmitted = false;
        },
      });
  }

  async deleteFastingPerson(fastingPerson: FastingPerson) {
    const alert = await this.alertController.create({
      header: 'Warning',
      message: `You are going to delete ${fastingPerson.firstName} ${fastingPerson.lastName} from fasting persons.`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel',
          cssClass: 'ion-color-danger',
        },
        {
          text: 'Confirm',
          role: 'confirm',
          handler: () => {
            this.fastingPersonService
              .deleteFastingPerson(fastingPerson)
              .subscribe(() => {
                this.fastingPersonService.getFastingPersons();
                this.router.navigate(['pages']);
              });
          },
        },
      ],
    });

    await alert.present();
  }

  getDate = (date?) => {
    return fn.getDate(date);
  };
}
