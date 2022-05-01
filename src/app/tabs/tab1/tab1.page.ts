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
      id: '5',
      name: 'emilia',
    },
    {
      id: '6',
      name: 'john',
    },
    {
      id: '7',
      name: 'emilio',
    },
    {
      id: '8',
      name: 'emilio',
    },
    {
      id: '9',
      name: 'emilio',
    },
    {
      id: '10',
      name: 'emilio',
    },
    {
      id: '11',
      name: 'emilio',
    },
    {
      id: '12',
      name: 'emilio',
    },
    {
      id: '13',
      name: 'emilio',
    },
    {
      id: '14',
      name: 'emilio',
    },
    {
      id: '15',
      name: 'emilio',
    },
    {
      id: '16',
      name: 'emilio',
    },
    {
      id: '17',
      name: 'emilio',
    },
    {
      id: '49',
      name: 'emilio',
    },
    {
      id: '445',
      name: 'emilio',
    },
    {
      id: '47',
      name: 'emilio',
    },
    {
      id: '48',
      name: 'emilio',
    },
    {
      id: '43',
      name: 'emilio',
    },
    {
      id: '41',
      name: 'emilio',
    },
    {
      id: '44',
      name: 'emilio',
    },
    {
      id: '99',
      name: 'emilio',
    },
    {
      id: '90',
      name: 'emilio',
    },
    {
      id: '88',
      name: 'emilio',
    },
    {
      id: '80',
      name: 'emilio',
    },
    {
      id: '100',
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
