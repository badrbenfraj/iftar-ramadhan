import { Component, OnInit } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';
import { first } from 'rxjs/operators';
import { FastingPerson } from 'src/app/core/model/fasting-person.model';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-person-details',
  templateUrl: 'person-details.page.html',
  styleUrls: ['person-details.page.scss'],
})
export class PersonDetailsPage implements OnInit {
  fastingPerson: FastingPerson;
  isMealTaken = false;
  constructor(
    private activeRoute: ActivatedRoute,
    private router: Router,
    private fastingPersonService: FastingPersonService
  ) {}
  ngOnInit(): void {
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
          this.fastingPerson = person?.data ? (person?.data as FastingPerson) : undefined;
          this.isMealTaken =
            new Date(this.fastingPerson.lastTakenMeal).setHours(0, 0, 0, 0) ===
            new Date().setHours(0, 0, 0, 0);
        });
    });
  }

  confirmMealTaken() {
    this.fastingPerson.lastTakenMeal = new Date().toISOString();
    this.fastingPersonService.updateFastingPerson(this.fastingPerson);
    this.getFastingPerson();
  }

  editPersonDetails(person) {
    this.router.navigate(['/pages/person/edit', person.id]);
  }
}
