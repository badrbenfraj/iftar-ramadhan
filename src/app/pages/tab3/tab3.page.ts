import { Component, OnInit } from '@angular/core';
import { filter, map } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-tab3',
  templateUrl: 'tab3.page.html',
  styleUrls: ['tab3.page.scss'],
})
export class Tab3Page implements OnInit {
  fastingPersonsList: FastingPerson[] = [];

  constructor(private fastingPersonService: FastingPersonService) {}

  ngOnInit(): void {
    this.getFastionsPersonsList();
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
        )
      )
      .subscribe((items) => (this.fastingPersonsList = items));
  }

  getMealsNumber() {
    let fastingPeople = 0;
    for (const person of this.fastingPersonsList) {
      fastingPeople += person.fasting;
    }
    return fastingPeople;
  }
}
