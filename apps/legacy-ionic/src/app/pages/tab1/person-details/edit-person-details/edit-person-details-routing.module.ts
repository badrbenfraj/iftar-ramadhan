import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { EditPersonDetailsPage } from './edit-person-details.page';

const routes: Routes = [
  {
    path: ':code',
    component: EditPersonDetailsPage,
  }
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
  exports: [RouterModule]
})
export class EditPersonDetailsPageRoutingModule {}
