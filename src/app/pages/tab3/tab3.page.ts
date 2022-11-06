import { Component, OnInit } from '@angular/core';
import { map } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';
import { PDFGenerator } from '@awesome-cordova-plugins/pdf-generator/ngx';

@Component({
  selector: 'app-tab3',
  templateUrl: 'tab3.page.html',
  styleUrls: ['tab3.page.scss'],
})
export class Tab3Page implements OnInit {
  content: string;
  fastingPersonsList: FastingPerson[] = [];

  constructor(
    private fastingPersonService: FastingPersonService,
    private pdfGenerator: PDFGenerator
  ) {}

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

  downloadPDF() {
    this.content = document.getElementById('PrintStats').innerHTML;

    const options = {
      type: 'share',
      fileName: `statistics_${new Date().getDate()}_${new Date().getMonth()}_${new Date().getFullYear()}.pdf`,
    };
    this.pdfGenerator
      .fromData(this.content, options)
      .then((base64String) => console.log(base64String));
  }
}
