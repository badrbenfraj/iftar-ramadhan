import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { AlertController } from '@ionic/angular';
import { first } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-edit-person-details',
  templateUrl: 'edit-person-details.page.html',
  styleUrls: ['edit-person-details.page.scss'],
})
export class EditPersonDetailsPage implements OnInit {
  fastingPerson: FastingPerson;

  fastingPersonForm: FormGroup;

  isSubmitted: boolean;

  constructor(
    private activeRoute: ActivatedRoute,
    private router: Router,
    private formBuilder: FormBuilder,
    private alertController: AlertController,
    private fastingPersonService: FastingPersonService
  ) {}

  get form() {
    return this.fastingPersonForm.controls;
  }

  ngOnInit(): void {
    this.fastingPersonForm = this.formBuilder.group({
      code: ['', [Validators.required]],
      firstName: ['', [Validators.required]],
      lastName: ['', [Validators.required]],
      familyMeal: [null, [Validators.required]],
      singleMeal: [null, [Validators.required]],
      lastTakenMeal: ['', []],
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
          this.fastingPerson = person.length
            ? (person[0] as FastingPerson)
            : undefined;
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
      return;
    }

    const firstName = this.form.firstName.value;
    const lastName = this.form.lastName.value;
    const familyMeal = this.form.familyMeal.value;
    const singleMeal = this.form.singleMeal.value;
    const lastTakenMeal = this.form.lastTakenMeal.value;
    const code = this.form.code.value;
    const id = this.fastingPerson.id;

    this.fastingPersonService
      .updateFastingPerson({
        id,
        code,
        firstName,
        lastName,
        singleMeal,
        familyMeal,
        lastTakenMeal,
      })
      .then(() => {
        this.isSubmitted = false;
        this.fastingPersonForm.reset();
        this.router.navigate(['pages']);
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
              .then(() => {
                this.router.navigate(['pages']);
              });
          },
        },
      ],
    });

    await alert.present();
  }
}
