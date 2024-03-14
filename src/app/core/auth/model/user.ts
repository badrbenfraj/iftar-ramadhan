export interface User {
  email: string;
  name: string;
  username: string;
  password: string;
  roles: string[];
  isAccountDisabled: boolean;
}
