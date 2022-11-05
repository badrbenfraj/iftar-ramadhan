import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { PagesPage } from './pages.page';

const routes: Routes = [
  {
    path: '',
    component: PagesPage,
    children: [
      {
        path: 'list',
        loadChildren: () =>
          import('./tab1/tab1.module').then((m) => m.Tab1PageModule),
      },
      {
        path: 'tab2',
        loadChildren: () =>
          import('./tab2/tab2.module').then((m) => m.Tab2PageModule),
      },
      {
        path: 'tab3',
        loadChildren: () =>
          import('./tab3/tab3.module').then((m) => m.Tab3PageModule),
      },
      {
        path: 'tab-profile',
        loadChildren: () =>
          import('./tab-profile/tab-profile.module').then(
            (m) => m.TabProfilePageModule
          ),
      },
      {
        path: '',
        redirectTo: '/pages/list',
        pathMatch: 'full',
      },
    ],
  },
  {
    path: '',
    redirectTo: '/pages/list',
    pathMatch: 'full',
  },
  {
    path: 'scan',
    loadChildren: () =>
      import('./scan/scan.module').then((m) => m.ScanPageModule),
  },
  {
    path: 'person',
    loadChildren: () =>
      import('./tab1/person-details/person-details.module').then(
        (m) => m.PersonDetailsModule
      ),
  },
];

@NgModule({
  imports: [RouterModule.forChild(routes)],
})
export class PagesPageRoutingModule {}
