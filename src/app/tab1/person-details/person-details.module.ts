import { IonicModule } from '@ionic/angular';
import { RouterModule } from '@angular/router';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { PersonDetailsPage } from './person-details.page';

import { PersonDetailsPageRoutingModule } from './person-details-routing.module';

@NgModule({
  imports: [
    IonicModule,
    CommonModule,
    FormsModule,
    RouterModule.forChild([{ path: '', component: PersonDetailsPage }]),
    CommonModule,
    PersonDetailsPageRoutingModule
  ],
  declarations: [PersonDetailsPage]
})
export class PersonDetailsModule {}
