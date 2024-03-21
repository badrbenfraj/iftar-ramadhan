import { Component, OnInit, inject } from '@angular/core';
import { Router } from '@angular/router';
import { FastingPerson } from '@app/core/model/fasting-person.model';
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

  loading = false;

  constructor(private router: Router) {}

  ngOnInit(): void {
    // const asyncLoop = async () => {
    //   try {
    //     for (let i = 0; i < 1000; i++) {
    //       await this.fastingPersonService.addFastingPerson(json[i]).toPromise();
    //       console.log(`Request ${i} completed.`);
    //     }
    //     console.log("All requests completed.");
    //   } catch (error) {
    //     console.error('Error fetching data:', error);
    //   }
    // }
    // asyncLoop();
    this.getFastingPersons();
  }

  personDetails(person) {
    this.router.navigate(['/pages/person/details', person.id]);
  }

  refreshFastingPeople(event) {
    this.loading = true;
    this.getFastingPersons();
    this.fastingPersonService.fastingPeople$.subscribe({
      complete: () => {
        this.loading = false;
        event.target.complete();
      },
      error: (error) => {
        this.loading = false;
        event.target.complete();
      },
    });
  }

  getFastingPersons() {
    return this.fastingPersonService.getFastingPersons();
  }
}
