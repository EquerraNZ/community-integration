import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { config, ConfigurationError, resetConfigCache } from "../src/shared/config.js";

const SAVED = { ...process.env };

beforeEach(() => {
  resetConfigCache();
});

afterEach(() => {
  process.env = { ...SAVED };
  resetConfigCache();
});

describe("config", () => {
  it("names the setting when it is missing", () => {
    delete process.env["BC_COMPANY_ID"];
    expect(() => config.bcCompanyId()).toThrow(/BC_COMPANY_ID/);
    expect(() => config.bcCompanyId()).toThrow(ConfigurationError);
  });

  it("treats an empty setting as missing", () => {
    process.env["BC_COMPANY_ID"] = "   ";
    expect(() => config.bcCompanyId()).toThrow(/BC_COMPANY_ID/);
  });

  it("rejects a URL that is not a URL, naming the setting", () => {
    process.env["WMS_BASE_URL"] = "wms.example.com";
    expect(() => config.wmsBaseUrl()).toThrow(/WMS_BASE_URL/);
  });

  it("rejects a plain http URL", () => {
    // Everything the plane calls is https. An http setting is a mistake worth
    // catching at startup rather than a downgrade nobody notices.
    process.env["WMS_BASE_URL"] = "http://wms.example.com";
    expect(() => config.wmsBaseUrl()).toThrow(/must be https/);
  });

  it("strips a trailing slash so callers can concatenate a path", () => {
    process.env["WMS_BASE_URL"] = "https://wms.example.com/";
    expect(config.wmsBaseUrl()).toBe("https://wms.example.com");
  });

  it("reads a secret by setting name", () => {
    process.env["WMS_API_KEY"] = "secret-value";
    expect(config.secret("WMS_API_KEY")).toBe("secret-value");
  });
});
