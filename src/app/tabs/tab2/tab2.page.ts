import { Component, OnInit } from '@angular/core';
import { FormBuilder, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-tab2',
  templateUrl: 'tab2.page.html',
  styleUrls: ['tab2.page.scss'],
})
export class Tab2Page implements OnInit {
  fastingPersonForm;
  isSubmitted: boolean;

  constructor(
    private fastingPersonService: FastingPersonService,
    private router: Router,
    private formBuilder: FormBuilder
  ) {}

  get form() {
    return this.fastingPersonForm.controls;
  }

  ngOnInit() {
    this.fastingPersonForm = this.formBuilder.group({
      firstName: ['', [Validators.required]],
      lastName: ['', [Validators.required]],
      fasting: ['', [Validators.required]],
    });
  }

  onSubmit() {
    this.isSubmitted = true;

    if (this.fastingPersonForm.invalid) {
      return;
    }

    const firstName = this.form.firstName.value;
    const lastName = this.form.lastName.value;
    const fasting = this.form.fasting.value;

    this.fastingPersonService
      .addFastingPerson({
        firstName,
        lastName,
        fasting,
      })
      .then(() => {
        this.isSubmitted = false;
        this.fastingPersonForm.reset();
        this.router.navigate(['tabs']);
      });
  }
}
