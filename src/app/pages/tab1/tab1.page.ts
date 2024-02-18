import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { Observable } from 'rxjs';
import { first, map } from 'rxjs/operators';
import { FastingPersonService } from 'src/app/core/service/fasting-person.service';

@Component({
  selector: 'app-tab1',
  templateUrl: 'tab1.page.html',
  styleUrls: ['tab1.page.scss'],
})
export class Tab1Page implements OnInit {
  searchTerm: string;

  fastingPeople$: Observable<any[]>;

  constructor(
    private fastingPersonService: FastingPersonService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.getFastingPersons();
  }

  personDetails(person) {
    this.router.navigate(['/pages/person/details', person.code]);
  }

  refreshFastingPeople(event) {
    this.getFastingPersons().then(() => {
      event.target.complete();
    });
  }

  async getFastingPersons() {
    this.fastingPeople$ = await this.fastingPersonService
      .getFastingPersons()
      .pipe(
        first(),
        map((items) => items.sort((a, b) => a.code - b.code))
      );
  }
}
