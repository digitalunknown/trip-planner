/**
 * Compatibility shim: POST /api/parsePaste → same handler as /api/ai (plan_day).
 * Prefer /api/ai for new clients.
 */
import aiHandler from "./ai.js";

export default async function handler(req, res) {
  if (req.method === "POST") {
    const body = typeof req.body === "string" ? JSON.parse(req.body || "{}") : req.body ?? {};
    if (!body.mode) {
      body.mode = "plan_day";
    }
    req.body = body;
  }
  return aiHandler(req, res);
}
