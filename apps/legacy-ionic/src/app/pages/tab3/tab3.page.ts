import { Component, OnInit, inject } from '@angular/core';
import { first, map } from 'rxjs/operators';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import { Bulk } from '@app/core/model/bulk.model';
import {
  UntypedFormBuilder,
  UntypedFormGroup,
  Validators,
} from '@angular/forms';
import { DatePipe } from '@angular/common';

@Component({
  selector: 'app-tab3',
  templateUrl: 'tab3.page.html',
  styleUrls: ['tab3.page.scss'],
  providers: [DatePipe],
})
export class Tab3Page implements OnInit {
  form: UntypedFormGroup;

  formBuilder = inject(UntypedFormBuilder);

  datePipe = inject(DatePipe);

  content: string;

  loading: boolean = false;

  isDataLoaded: boolean = false;

  data: any;

  showTo = false;

  showFrom = false;

  constructor(private fastingPersonService: FastingPersonService) {}

  ngOnInit(): void {
    this.form = this.formBuilder.group(
      {
        fromDate: [new Date().toISOString(), [Validators.required]],
        toDate: [new Date().toISOString(), [Validators.required]],
      },
      { validators: this.dateRangeValidator }
    );
  }

  toDateChanged() {
    console.log(this.form);
    setTimeout(() => {
      this.showTo = false;
    }, 150);
  }

  fromDateChanged() {
    setTimeout(() => {
      this.showFrom = false;
    }, 150);
  }

  retry() {
    this.form.reset();
    this.data = [];
    this.isDataLoaded = false;
  }

  validate() {
    this.loading = true;
    this.fastingPersonService
      .getStatistics(this.form.getRawValue())
      .pipe(first())
      .subscribe({
        next: (data) => {
          this.data = data?.data;
          this.loading = false;
          this.isDataLoaded = true;
        },
        error: () => {
          this.loading = false;
          this.isDataLoaded = false;
        },
      });
  }

  visibilityTo() {
    this.showTo = !this.showTo;
    this.showFrom = false;
  }

  visibilityFrom() {
    this.showFrom = !this.showFrom;
    this.showTo = false;
  }

  validateReadOnly() {
    return (
      !this.form.value.fromDate || !this.form.value.toDate || this.form.invalid
    );
  }

  selectionChanged(selected) {
    switch (selected.detail.value) {
      case 'daily':
        this.form.patchValue({
          fromDate: new Date().toISOString(),
          toDate: new Date().toISOString(),
        });
        break;
      case 'weekly':
        const curr = new Date();
        const currDate = new Date(
          curr.getFullYear(),
          curr.getMonth(),
          curr.getDate()
        );

        const firstDayOfWeek = currDate.getDate() - currDate.getDay();
        const lastDayOfWeek = firstDayOfWeek + 6;
        const startDateOfWeek = new Date(currDate);
        startDateOfWeek.setDate(firstDayOfWeek);
        const endDateOfWeek = new Date(currDate);
        endDateOfWeek.setDate(lastDayOfWeek);

        this.form.patchValue({
          fromDate: startDateOfWeek.toISOString(),
          toDate: endDateOfWeek.toISOString(),
        });
        break;
      case 'monthly':
        const current = new Date();

        const firstDayOfMonth = new Date(
          current.getFullYear(),
          current.getMonth(),
          1
        );
        const lastDayOfMonth = new Date(
          current.getFullYear(),
          current.getMonth() + 1,
          0
        );

        this.form.patchValue({
          fromDate: firstDayOfMonth.toISOString(),
          toDate: lastDayOfMonth.toISOString(),
        });
        break;
      case 'custom':
        break;
    }
  }

  getWeeklyStats() {
    const curr = new Date(new Date().setHours(0, 0, 0, 0));
    const firstday = curr.getDate() - curr.getDay() + 1;
    const lastday = firstday + 6;

    new Date(curr.setDate(firstday));
    new Date(curr.setDate(lastday));
  }

  downloadPDF() {
    this.content = document.getElementById('PrintStats').innerHTML;

    const date = new Date().getDate();
    const month = new Date().getMonth();
    const year = new Date().getFullYear();
    this.fastingPersonService.downloadDailyStatistics().subscribe();
    const options = {
      type: 'share',
      fileName: `statistics_${date}_${month}_${year}.pdf`,
    };
  }

  refreshStats(event) {
    this.loading = true;
    this.fastingPersonService
      .getStatistics(this.form.getRawValue())
      .pipe(first())
      .subscribe({
        next: (data) => {
          this.data = data?.data;
          this.loading = false;
          this.isDataLoaded = true;
          event.target.complete();
        },
        error: () => {
          this.loading = false;
          this.isDataLoaded = false;
          event.target.complete();
        },
      });
  }

  getFromDate() {
    if (this.form.get('fromDate').value) {
      return this.datePipe.transform(this.form.get('fromDate').value);
    } else {
      return 'Choose a Date';
    }
  }

  getToDate() {
    if (this.form.get('toDate').value) {
      return this.datePipe.transform(this.form.get('toDate').value);
    } else {
      return 'Choose a Date';
    }
  }

  dateRangeValidator(formGroup: UntypedFormGroup) {
    const fromDate = formGroup.get('fromDate').value;
    const toDate = formGroup.get('toDate').value;

    if (fromDate && toDate) {
      return fromDate <= toDate ? null : { rangeInvalid: true };
    }
    return null;
  }
}
