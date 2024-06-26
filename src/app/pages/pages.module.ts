import { IonicModule } from '@ionic/angular';
import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

import { PagesPageRoutingModule } from './pages-routing.module';

import { PagesPage } from './pages.page';

@NgModule({
  imports: [
    IonicModule,
    CommonModule,
    FormsModule,
    PagesPageRoutingModule
  ],
  declarations: [PagesPage]
})
export class PagesPageModule {}
