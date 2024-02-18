import { Component, OnDestroy, OnInit } from '@angular/core';
import {
  FormBuilder,
  FormControl,
  FormGroup,
  Validators,
} from '@angular/forms';
import { Router } from '@angular/router';
import { Subject } from 'rxjs';
import { take } from 'rxjs/operators';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-tab2',
  templateUrl: 'tab2.page.html',
  styleUrls: ['tab2.page.scss'],
})
export class Tab2Page implements OnInit, OnDestroy {
  fastingPersonForm: FormGroup;

  bulkMealsForm;

  bulkMode = false;

  isSubmitted: boolean;

  isBulkSubmitted: boolean;

  private destroy$ = new Subject();

  constructor(
    private fastingPersonService: FastingPersonService,
    private router: Router,
    private formBuilder: FormBuilder
  ) {}

  get form() {
    return this.fastingPersonForm.controls;
  }

  get bulkForm() {
    return this.bulkMealsForm.controls;
  }

  ngOnInit() {
    this.fastingPersonForm = this.formBuilder.group({
      code: ['', [Validators.required]],
      firstName: ['', [Validators.required]],
      lastName: ['', [Validators.required]],
      familyMeal: [null, [Validators.required]],
      singleMeal: [null, [Validators.required]],
      lastTakenMeal: ['', []],
    });

    this.bulkMealsForm = this.formBuilder.group({
      familyMeal: [null, [Validators.required]],
      singleMeal: [null, [Validators.required]],
      creationDate: [new Date(), []],
    });

    this.fastingPersonService
      .getFastingPersonsCount()
      .pipe(take(1))
      .subscribe((settings) => {
        this.fastingPersonForm.patchValue({
          code: settings['fasting-person-count'] + 1,
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

    this.fastingPersonService
      .addFastingPerson({
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
        this.bulkMealsForm.reset();
        this.router.navigate(['pages']);
        this.fastingPersonService.updateFastingPersonCount({
          'fasting-person-count': code,
        });

        this.fastingPersonService
          .getFastingPersonsCount()
          .pipe(take(1))
          .subscribe((settings) => {
            this.fastingPersonForm.patchValue({
              code: settings['fasting-person-count'] + 1,
            });
          });
      });
  }

  validateMealForm() {
    if (
      this.form.singleMeal?.value === 0 ||
      this.form.familyMeal?.value === 0
    ) {
      this.form.controls.get('singleMeal').setErrors({ incorrect: true });
      return true;
    } else {
      return false;
    }
  }

  onBulkSubmit() {
    this.isBulkSubmitted = true;

    if (this.bulkForm.singleMeal?.value === 0) {
      this.bulkForm.singleMeal.setErrors({ incorrect: true });
    }

    if (this.bulkForm.familyMeal?.value === 0) {
      this.bulkForm.familyMeal.setErrors({ incorrect: true });
    }

    if (
      this.bulkForm.singleMeal?.value > 0 &&
      !this.bulkForm.familyMeal?.value
    ) {
      this.bulkForm.familyMeal.patchValue(0);
    }

    if (
      this.bulkForm.familyMeal?.value > 0 &&
      !this.bulkForm.singleMeal?.value
    ) {
      this.bulkForm.singleMeal.patchValue(0);
    }

    if (this.bulkMealsForm.invalid) {
      return;
    }

    const familyMeal = this.bulkForm.familyMeal.value;
    const singleMeal = this.bulkForm.singleMeal.value;
    const creationDate = new Date(new Date().setHours(0, 0, 0, 0));

    this.fastingPersonService
      .addBulkMeals({
        singleMeal,
        familyMeal,
        creationDate,
      })
      .then(() => {
        this.isBulkSubmitted = false;
        this.fastingPersonForm.reset();
        this.bulkMealsForm.reset();
        this.bulkMode = false;
        this.router.navigate(['pages']);
      });
  }

  changeMode() {
    this.bulkMode = !this.bulkMode;
  }

  ngOnDestroy(): void {
    this.destroy$.next(true);
    this.destroy$.complete();
  }
}
