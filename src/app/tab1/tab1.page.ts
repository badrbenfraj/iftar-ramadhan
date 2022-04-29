import { Component } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-tab1',
  templateUrl: 'tab1.page.html',
  styleUrls: ['tab1.page.scss'],
})
export class Tab1Page {
  searchTerm: string;

  fastingPeople: any[] = [
    {
      id: '1',
      name: 'badr',
    },
    {
      id: '2',
      name: 'sami',
    },
    {
      id: '3',
      name: 'john',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
    {
      id: '4',
      name: 'emilio',
    },
  ];

  constructor(private router: Router) {}

  personDetails(person) {
    this.router.navigate(['/tabs/person/details', person.id]);
  }

  refreshFastingPeople(event) {
    setTimeout(() => {
      this.fastingPeople = [
        {
          id: '1',
          name: 'badr',
        },
        {
          id: '2',
          name: 'sami',
        },
        {
          id: '3',
          name: 'john',
        },
      ];
      event.target.complete();
    }, 3000);
  }
}
