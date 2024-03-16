import { Region } from "../enums/regions.enum";

export interface FastingPerson {
  id: number;
  firstName: string;
  lastName: string;
  region?: Region;
  singleMeal: number;
  familyMeal: number;
  lastTakenMeal?: string;
}
