import { Component, OnDestroy, OnInit } from '@angular/core';
import {
  UntypedFormBuilder,
  FormControl,
  UntypedFormGroup,
  Validators,
} from '@angular/forms';
import { Router } from '@angular/router';
import { Subject } from 'rxjs';
import { concatMap, take } from 'rxjs/operators';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-tab2',
  templateUrl: 'tab2.page.html',
  styleUrls: ['tab2.page.scss'],
})
export class Tab2Page implements OnInit, OnDestroy {
  fastingPersonForm: UntypedFormGroup;

  bulkMealsForm;

  bulkMode = false;

  isSubmitted: boolean;

  isBulkSubmitted: boolean;

  private destroy$ = new Subject();

  constructor(
    private fastingPersonService: FastingPersonService,
    private router: Router,
    private formBuilder: UntypedFormBuilder
  ) {}

  get form() {
    return this.fastingPersonForm.controls;
  }

  get bulkForm() {
    return this.bulkMealsForm.controls;
  }

  ngOnInit() {
    this.fastingPersonForm = this.formBuilder.group({
      id: [null, [Validators.required]],
      firstName: ['', [Validators.required]],
      lastName: ['', [Validators.required]],
      familyMeal: [null, [Validators.required]],
      singleMeal: [null, [Validators.required]],
      region: [null, [Validators.required]],
      phone: [null, []],
      comment: [null, []],
      cameToday: [true, []],
    });

    this.bulkMealsForm = this.formBuilder.group({
      familyMeal: [null, [Validators.required]],
      singleMeal: [null, [Validators.required]],
      creationDate: [new Date(), []],
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
      .addFastingPerson(this.fastingPersonForm.getRawValue())
      .subscribe({
        next: () => {
          this.isSubmitted = false;
          this.fastingPersonForm.reset();
          this.bulkMealsForm.reset();
          this.router.navigate(['pages']);
        },
        error: (error) => {
          this.isSubmitted = false;
        },
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
      this.isSubmitted = false;
      return;
    }

    const familyMeal = this.bulkForm.familyMeal.value;
    const singleMeal = this.bulkForm.singleMeal.value;
    const creationDate = new Date(new Date().setHours(0, 0, 0, 0));

    // this.fastingPersonService
    //   .addBulkMeals({
    //     singleMeal,
    //     familyMeal,
    //     creationDate,
    //   })
    //   .then(() => {
    //     this.isBulkSubmitted = false;
    //     this.fastingPersonForm.reset();
    //     this.bulkMealsForm.reset();
    //     this.bulkMode = false;
    //     this.router.navigate(['pages']);
    //   });
  }

  changeMode() {
    this.bulkMode = !this.bulkMode;
  }

  getTodayDate() {
    return new Date(new Date().setHours(0, 0, 0, 0)).toISOString();
  }

  ngOnDestroy(): void {
    this.destroy$.next(true);
    this.destroy$.complete();
  }
}
