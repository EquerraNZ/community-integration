import { describe, expect, it } from "vitest";
import { classifyError, classifyStatus, HttpFailure } from "../src/shared/classify.js";

describe("classifyStatus", () => {
  it.each([408, 429, 500, 502, 503, 504])("treats %i as transient", (status) => {
    expect(classifyStatus(status)).toBe("transient");
  });

  it.each([400, 401, 403, 404, 409, 422])("treats %i as permanent", (status) => {
    expect(classifyStatus(status)).toBe("permanent");
  });
});

describe("classifyError", () => {
  it.each(["ETIMEDOUT", "ECONNRESET", "UND_ERR_CONNECT_TIMEOUT"])(
    "treats a %s network error as transient",
    (code) => {
      expect(classifyError(Object.assign(new Error("boom"), { code }))).toBe("transient");
    },
  );

  it("follows an error cause to find the code", () => {
    const error = new Error("fetch failed", { cause: Object.assign(new Error("inner"), { code: "ECONNRESET" }) });
    expect(classifyError(error)).toBe("transient");
  });

  it("treats a timeout message as transient", () => {
    expect(classifyError(new Error("The operation timed out"))).toBe("transient");
  });

  it("takes the status from an HttpFailure", () => {
    expect(classifyError(new HttpFailure("WMS", 503))).toBe("transient");
    expect(classifyError(new HttpFailure("WMS", 422))).toBe("permanent");
  });

  it("treats an error it cannot place as permanent", () => {
    // The opposite default retries an unknown bug five times per message against
    // an external system that is working fine.
    expect(classifyError(new TypeError("undefined is not a function"))).toBe("permanent");
  });
});
