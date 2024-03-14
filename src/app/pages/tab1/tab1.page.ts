import { Component, OnInit, inject } from '@angular/core';
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
  fastingPersonService = inject(FastingPersonService);

  searchTerm: string;

  constructor(private router: Router) {}

  ngOnInit(): void {
    this.getFastingPersons();
  }

  personDetails(person) {
    this.router.navigate(['/pages/person/details', person.id]);
  }

  refreshFastingPeople(event) {
    this.getFastingPersons();
    this.fastingPersonService.fastingPeople$.subscribe({
      complete: () => {
        event.target.complete();
      },
    });
  }

  getFastingPersons() {
    return this.fastingPersonService.getFastingPersons();
  }
}
