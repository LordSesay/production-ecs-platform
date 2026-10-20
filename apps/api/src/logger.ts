export const log = {
  info: (data: object) => console.info(JSON.stringify(data)),
  error: (data: object) => console.error(JSON.stringify(data)),
  sanitize: (value: string) => value.replace(/[\r\n]/g, ""),
};
