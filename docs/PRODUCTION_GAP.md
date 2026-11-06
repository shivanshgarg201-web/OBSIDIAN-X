# From demo to real deployment

## Not yet implemented
- Real geographic map tiles, route alternatives and navigation instructions
- GPS reading and background location tracking
- Server-side hazard feeds and official disaster alerts
- Authentication, authorization, encrypted data protection
- Verified SOS dispatch to opted-in trusted contacts
- Push notifications with delivery acknowledgements
- Offline hazard-cache expiry and fault handling
- Validated/ground-truth safety scores and closure filtering
- Hospitals or public emergency dispatch integrations
- Trained ML forecasting and AI emergency assistant

## Suggested integration sequence
1. Map SDK, Routes API and destination geocoding (requires credentials/billing).
2. Location permission flow, explicit tracking consent, cancel/revoke/share expiry.
3. Node.js API serving real polylines and test geometries.
4. Firestore hazard model with timestamps, authoritative source tags, and verification; never treat absent data as safety.
5. Risk scoring with geographical intersection tests and coverage metadata.
6. Firebase Authentication, Firestore Security Rules, App Check and server-side notification triggers.
7. Trusted-contact onboarding and delivery acknowledgment. Never label locally-recorded SOS as transmitted.
8. Test emergency behavior extensively under network and location failure modes.

## Privacy / responsibility
- Data minimization and encryption are necessary before collecting real GPS data.
- Current demo records **no real GPS location** and does not communicate externally.
- A UI toggle labelled sharing is **not an operational tracking mechanism**.
- For real emergencies users must contact local emergency services.
