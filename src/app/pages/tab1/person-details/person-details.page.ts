import { Component, OnInit, inject } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { first } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import * as fn from '@app/shared/functions/functions-expression';
import { UntypedFormBuilder, UntypedFormGroup } from '@angular/forms';

@Component({
  selector: 'app-person-details',
  templateUrl: 'person-details.page.html',
  styleUrls: ['person-details.page.scss'],
})
export class PersonDetailsPage implements OnInit {
  fastingPerson: FastingPerson;

  isMealTaken = false;

  editable = false;

  form: UntypedFormGroup;

  formBuilder = inject(UntypedFormBuilder);

  constructor(
    private activeRoute: ActivatedRoute,
    private router: Router,
    private fastingPersonService: FastingPersonService
  ) {}
  ngOnInit(): void {
    this.form = this.formBuilder.group({
      region: [null, []],
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
          this.form.patchValue({
            ...this.fastingPerson,
          });
          this.isMealTaken =
            this.getDate(this.fastingPerson.lastTakenMeal) === this.getDate();
        });
    });
  }

  confirmMealTaken() {
    this.fastingPersonService
      .confirmMeal({ ...this.fastingPerson, ...this.form.getRawValue() })
      .subscribe({
        next: () => {
          this.isMealTaken = true;
        },
        error: (error) => {
          this.isMealTaken = false;
        },
      });
  }

  getDate(date?) {
    return fn.getDate(date);
  }

  editPersonDetails(person) {
    this.router.navigate(['/pages/person/edit', person.id]);
  }
}
