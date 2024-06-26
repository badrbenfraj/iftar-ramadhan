import { IonicModule } from '@ionic/angular';
import { RouterModule } from '@angular/router';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { ScanPage } from './scan.page';

import { ScanPageRoutingModule } from './scan-routing.module';

@NgModule({
  imports: [
    RouterModule,
    IonicModule,
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    ScanPageRoutingModule,
  ],
  declarations: [ScanPage],
})
export class ScanPageModule {}
