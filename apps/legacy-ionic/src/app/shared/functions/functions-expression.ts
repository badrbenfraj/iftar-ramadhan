export function getDate(date?) {
  const t =
    (date && new Date(new Date(date).setHours(0, 0, 0, 0))) ||
    new Date(new Date().setHours(0, 0, 0, 0));

  const actiondate = new Date(t);
  return actiondate.getTime();
}
