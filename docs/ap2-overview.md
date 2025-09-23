# Agent Payments Protocol (AP2) – Notes

## Key Roles
- **User / User Agent (UA)**: Human + interface that delegates purchase tasks.
- **Shopping Agent (SA)**: Aggregates offers, negotiates carts, relays mandate drafts.
- **Merchant Agent (MA)**: Represents merchant systems, issues quotes/carts.
- **Payment Agent (PA)**: Trusted payment service provider; verifies mandates and executes payments.
- **Identity Provider**: Issues verifiable credentials (VCs) to participants.

## Mandate Chain
1. **Intent Mandate**: User authorizes agent to pursue a task (constraints: items, budget, timing).
2. **Cart Mandate**: Final cart snapshot (items, price, merchant) that user approves or pre-approves.
3. **Payment Mandate**: PA confirms payment method + mandate linkage for settlement.

Each mandate is a signed VC referencing previous state; signatures allow downstream verification.

## Trust & Transport
- Built on top of A2A (HTTP + Server Sent Events + JSON-RPC) and Model Context Protocol.
- Participants exchange signed payloads; PA enforces PCI/PII boundary (agents never see card data).
- Supports step-up challenges (biometrics, OTP) via mandate update flows.

## Implementation Notes for MyShop
- **Gateway Service**: REST endpoint (likely PHP/Laravel microservice or WP REST route) accepts AP2 Cart Mandate, validates signatures against trusted issuer list, and translates to WooCommerce order creation.
- **Payment Execution**: Use existing Stripe integration to create PaymentIntent matching cart total. Persist mandate metadata (`_ap2_mandate_id`, `_ap2_cart_hash`) on the order for auditing.
- **Secrets**: Need storage for AP2 trusted roots, signing keys if acting as UA/MA, and Stripe API keys (already env-configured).
- **Webhook Flow**: Payment completion triggers update back to PA/UA via AP2 callback (async). Requires queue or Action Scheduler job to push status.
- **Non-goals v0**: Push-payment methods, multi-merchant carts, autonomous inventory. Focus on single-merchant, card-based pull payments.

## Next Questions
- How to obtain/verifiy VC issuers? (Spec references trust registries; open TODO.)
- Official JSON schemas for mandates? (`docs/specification.md` section 4). Need to extract for validation.
- Authentication between agents: leverage OAuth mTLS? spec suggests parity with OpenAPI security.

