import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { PersonDetailsPage } from './person-details.page';

const routes: Routes = [
  {
    path: '',
    component: PersonDetailsPage,
  },
  {
    path: 'details/:code',
    component: PersonDetailsPage,
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule]
})
export class PersonDetailsPageRoutingModule {}