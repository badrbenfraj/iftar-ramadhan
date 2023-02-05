import { Component, OnInit } from '@angular/core';
import { first, map } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import { PDFGenerator } from '@awesome-cordova-plugins/pdf-generator/ngx';
import { Bulk } from '@app/core/model/bulk.model';

@Component({
  selector: 'app-tab3',
  templateUrl: 'tab3.page.html',
  styleUrls: ['tab3.page.scss'],
})
export class Tab3Page implements OnInit {
  content: string;

  fastingPersonsList: FastingPerson[] = [];

  bulkData: Bulk[] = [];

  constructor(
    private fastingPersonService: FastingPersonService,
    private pdfGenerator: PDFGenerator
  ) {}

  ngOnInit(): void {
    this.getFastionsPersonsList();
    this.fastingPersonService
      .getStatisticsByDate(new Date(new Date().setHours(0, 0, 0, 0)))
      .pipe(first())
      .subscribe((data) => (this.bulkData = data));
  }

  getFastionsPersonsList() {
    this.fastingPersonService
      .getFastingPersons()
      .pipe(
        map((items) =>
          items.filter(
            (item: FastingPerson) =>
              new Date(item.lastTakenMeal).setHours(0, 0, 0, 0) ===
              new Date().setHours(0, 0, 0, 0)
          )
        ),
        first()
      )
      .subscribe((items) => (this.fastingPersonsList = items));
  }

  getMealsNumber() {
    let fastingPeople = 0;
    for (const person of this.fastingPersonsList) {
      fastingPeople += person?.singleMeal + person?.familyMeal * 4;
    }
    return (
      fastingPeople +
      this.getSingleBulkMealsNumber() +
      this.getFamilyBulkMealsNumber()
    );
  }

  getSingleMealsNumber() {
    let fastingPeople = 0;
    for (const person of this.fastingPersonsList) {
      fastingPeople += person?.singleMeal;
    }
    return fastingPeople + this.getSingleBulkMealsNumber();
  }

  getFamilyMealsNumber() {
    let fastingPeople = 0;
    for (const person of this.fastingPersonsList) {
      fastingPeople += person?.familyMeal * 4;
    }
    return fastingPeople + this.getFamilyBulkMealsNumber();
  }

  getSingleBulkMealsNumber() {
    let fastingPeople = 0;
    for (const bulk of this.bulkData) {
      fastingPeople += bulk?.singleMeal;
    }
    return fastingPeople;
  }

  getFamilyBulkMealsNumber() {
    let fastingPeople = 0;
    for (const bulk of this.bulkData) {
      fastingPeople += bulk?.familyMeal * 4;
    }
    return fastingPeople;
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

    const options = {
      type: 'share',
      fileName: `statistics_${date}_${month}_${year}.pdf`,
    };
    this.pdfGenerator
      .fromData(this.content, options)
      .then((base64String) => console.log(base64String));
  }
}
