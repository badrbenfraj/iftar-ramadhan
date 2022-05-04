import { Component, OnInit } from '@angular/core';
import { ActivatedRoute } from '@angular/router';
import { first } from 'rxjs/operators';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-person-details',
  templateUrl: 'person-details.page.html',
  styleUrls: ['person-details.page.scss'],
})
export class PersonDetailsPage implements OnInit {
  fastingPerson: any;
  constructor(
    private activeRoute: ActivatedRoute,
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
        .getFastingPersonById(params.id)
        .pipe(first())
        .subscribe((person) => (this.fastingPerson = person));
    });
  }
}
