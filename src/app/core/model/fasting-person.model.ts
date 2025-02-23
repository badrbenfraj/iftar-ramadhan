import { Region } from "./region.model";

export interface FastingPerson {
  id: number;
  firstName: string;
  lastName: string;
  phone: string;
  comment: string;
  region: Region;
  singleMeal: number;
  familyMeal: number;
  lastTakenMeal?: Date;
  takenMeals: Date[];
}
