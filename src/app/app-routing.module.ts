import { NgModule } from '@angular/core';
import { PreloadAllModules, RouterModule, Routes } from '@angular/router';

const routes: Routes = [
  {
    path: 'home',
    loadChildren: () =>
      import('./home/home.module').then((m) => m.HomePageModule),
  },
  {
    path: 'pages',
    loadChildren: () =>
      import('./pages/pages.module').then((m) => m.PagesPageModule),
  },
  {
    path: 'register',
    loadChildren: () =>
      import('./core/auth/registration/registration.module').then(
        (m) => m.RegistrationPageModule
      ),
  },
  {
    path: 'login',
    loadChildren: () =>
      import('./core/auth/login/login.module').then(
        (m) => m.LoginPageModule
      ),
  },
  {
    path: 'verify-email',
    loadChildren: () =>
      import('./core/auth/verify-email/verify-email.module').then(
        (m) => m.VerifyEmailPageModule
      ),
  },
  {
    path: 'password-reset',
    loadChildren: () => import('./core/auth/password-reset/password-reset.module').then( m => m.PasswordResetPageModule)
  },
  {
    path: '',
    redirectTo: 'home',
    pathMatch: 'full',
  },
];
@NgModule({
  imports: [
    RouterModule.forRoot(routes, { preloadingStrategy: PreloadAllModules }),
  ],
  exports: [RouterModule],
})
export class AppRoutingModule {}
