import { Region } from "@app/core/enums/regions.enum";

export interface User {
  email: string;
  name: string;
  region: Region
  username: string;
  password: string;
  roles: string[];
  isAccountDisabled: boolean;
}
