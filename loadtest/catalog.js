import http from "k6/http";
import { check, sleep } from "k6";

export const options = {
  scenarios: {
    catalog_burst: {
      executor: "constant-arrival-rate",
      rate: Number(__ENV.RPS || 500),
      timeUnit: "1s",
      duration: __ENV.DURATION || "2m",
      preAllocatedVUs: Number(__ENV.VUS || 120),
      maxVUs: Number(__ENV.MAX_VUS || 500)
    }
  },
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<250"]
  }
};

const baseUrl = __ENV.BASE_URL || "http://localhost:4567";

export default function () {
  const catalog = http.get(`${baseUrl}/api/catalog`, {
    tags: { endpoint: "catalog" }
  });
  check(catalog, {
    "catalog status is 200": (response) => response.status === 200,
    "catalog has artists": (response) => response.json("artists").length > 0
  });

  if (__ITER % 20 === 0) {
    const follow = http.post(
      `${baseUrl}/api/follows`,
      JSON.stringify({ email: `load-${__VU}-${__ITER}@example.com`, artist_id: 1 }),
      { headers: { "Content-Type": "application/json" }, tags: { endpoint: "follows" } }
    );
    check(follow, { "follow accepted": (response) => response.status === 201 });
  }

  sleep(0.1);
}
