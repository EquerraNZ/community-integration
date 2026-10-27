/**
 * Every setting the plane reads, in one place, validated at first use.
 *
 * A missing setting fails loudly and names itself. The alternative, reading
 * `process.env.X` where it is needed, surfaces as `undefined` flowing into a URL
 * or a header and failing much later as something that looks like someone else's
 * bug.
 */

const cache = new Map<string, string>();

export class ConfigurationError extends Error {
  constructor(settingName: string, detail: string) {
    super(`Configuration setting ${settingName} ${detail}.`);
    this.name = "ConfigurationError";
  }
}

function read(name: string): string {
  const cached = cache.get(name);
  if (cached !== undefined) return cached;

  const raw = process.env[name];
  if (raw === undefined || raw.trim() === "") {
    throw new ConfigurationError(name, "is missing or empty");
  }

  const value = raw.trim();
  cache.set(name, value);
  return value;
}

function readUrl(name: string): string {
  const value = read(name);
  let parsed: URL;
  try {
    parsed = new URL(value);
  } catch {
    throw new ConfigurationError(name, `is not a valid URL (${value})`);
  }
  if (parsed.protocol !== "https:") {
    throw new ConfigurationError(name, `must be https (${parsed.protocol.replace(":", "")})`);
  }
  return value.replace(/\/+$/, "");
}

/** Clears the cache. Tests only: the host restarts rather than re-reading settings. */
export function resetConfigCache(): void {
  cache.clear();
}

export const config = {
  serviceBusNamespace: () => read("SERVICEBUS__fullyQualifiedNamespace"),

  bcBaseUrl: () => readUrl("BC_BASE_URL"),
  bcCompanyId: () => read("BC_COMPANY_ID"),
  bcTokenScope: () => read("BC_TOKEN_SCOPE"),
  bcEventEndpointUrl: () => readUrl("BC_EVENT_ENDPOINT_URL"),

  webstoreBaseUrl: () => readUrl("WEBSTORE_BASE_URL"),

  wmsBaseUrl: () => readUrl("WMS_BASE_URL"),

  /**
   * Secrets are app settings backed by Key Vault references, so the function
   * never calls the vault itself and never holds a vault client. Read by name so
   * a caller configures which secret it needs rather than importing a value.
   */
  secret: (settingName: string) => read(settingName),
} as const;
