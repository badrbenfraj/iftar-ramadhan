import { IonicModule } from '@ionic/angular';
import { RouterModule } from '@angular/router';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { EditPersonDetailsPage } from './edit-person-details.page';

import { EditPersonDetailsPageRoutingModule } from './edit-person-details-routing.module';

@NgModule({
  imports: [
    IonicModule,
    CommonModule,
    FormsModule,
    RouterModule.forChild([{ path: '', component: EditPersonDetailsPage }]),
    CommonModule,
    EditPersonDetailsPageRoutingModule,
    ReactiveFormsModule,
  ],
  declarations: [EditPersonDetailsPage],
})
export class EditPersonDetailsModule {}
