import { Region } from "@app/core/model/region.model";

export interface User {
  email: string;
  name: string;
  region: Region;
  username: string;
  password: string;
  roles: string[];
  isAccountDisabled: boolean;
}
