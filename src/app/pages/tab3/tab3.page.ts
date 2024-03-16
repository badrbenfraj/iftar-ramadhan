import { Component, OnInit } from '@angular/core';
import { first, map } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import { Bulk } from '@app/core/model/bulk.model';

@Component({
  selector: 'app-tab3',
  templateUrl: 'tab3.page.html',
  styleUrls: ['tab3.page.scss'],
})
export class Tab3Page implements OnInit {
  content: string;

  data: any;

  constructor(private fastingPersonService: FastingPersonService) {}

  ngOnInit(): void {
    this.fastingPersonService
      .getDailyStatistics()
      .pipe(first())
      .subscribe((data) => (this.data = data?.data));
  }

  get totalPersonsNumber() {
    return this.data?.totalPersons;
  }

  get personsNumber() {
    return this.data?.persons;
  }

  get mealsNumber() {
    return this.data?.totalMeals;
  }

  get singleMealsNumber() {
    return this.data?.singleMeal;
  }

  get familyMealsNumber() {
    return this.data?.familyMeal;
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
    this.fastingPersonService
    .downloadDailyStatistics().subscribe()
    const options = {
      type: 'share',
      fileName: `statistics_${date}_${month}_${year}.pdf`,
    };
  }

  refreshStats(event) {
    this.fastingPersonService
      .getDailyStatistics()
      .pipe(first())
      .subscribe((data) => {
        this.data = data?.data;
        event.target.complete();
      });
  }
}
