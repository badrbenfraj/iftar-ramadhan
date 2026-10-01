import { NgModule } from '@angular/core';
import { SearchPipe } from './filter.pipe';

@NgModule({
  declarations: [SearchPipe],
  exports: [SearchPipe]
})

export class SearchPipeModule { }
