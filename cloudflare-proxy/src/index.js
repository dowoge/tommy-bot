const ALLOWED_DOMAINS = [
	"users.roblox.com",
	"badges.roblox.com",
	"presence.roblox.com",
	"thumbnails.roblox.com",
	"inventory.roblox.com",
	"groups.roblox.com",
	"apis.roblox.com",
];

// Only forward these headers to the upstream API
const FORWARDED_HEADERS = [
	"content-type",
	"content-length",
	"accept",
	"x-api-key",
];

export default {
	async fetch(request, env) {
		// Validate shared secret
		const proxyKey = request.headers.get("X-Proxy-Key");
		if (!proxyKey || proxyKey !== env.PROXY_KEY) {
			return new Response("Unauthorized", { status: 403 });
		}

		// Get + validate target host
		const targetHost = request.headers.get("X-Target-Host");
		if (!targetHost || !ALLOWED_DOMAINS.includes(targetHost)) {
			return new Response("Invalid target host", { status: 403 });
		}

		// Go direct to Roblox
		const url = new URL(request.url);
		const targetUrl = `https://${targetHost}${url.pathname}${url.search}`;

		// Build clean headers — only forward essential ones
		const forwardHeaders = new Headers();
		for (const name of FORWARDED_HEADERS) {
			const value = request.headers.get(name);
			if (value) {
				forwardHeaders.set(name, value);
			}
		}

		// Forward the request
		const response = await fetch(targetUrl, {
			method: request.method,
			headers: forwardHeaders,
			body: request.method !== "GET" && request.method !== "HEAD"
				? request.body
				: undefined,
		});

		// Stream the response back directly
		return new Response(response.body, {
			status: response.status,
			statusText: response.statusText,
			headers: response.headers,
		});
	},
};
