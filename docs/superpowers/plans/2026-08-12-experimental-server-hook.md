# Experimental Server Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prototype a disabled-by-default Java agent that emits minimal B42 server observations to the companion without modifying game decisions.

**Architecture:** The agent is attached only to the dedicated-server JVM with `-javaagent`. It verifies a pinned B42 class fingerprint, observes one allowlisted server lifecycle method after its original return, and posts bounded telemetry to the loopback companion. Unsupported builds or all failures leave the server running with no transformer installed.

**Tech Stack:** Java 25, Gradle, Byte Buddy, JUnit 5, Project Zomboid B42 dedicated-server runtime.

## Global Constraints

- Server-only; do not inspect, modify, or promise detection of client processes.
- Default configuration is disabled.
- Do not alter PZ inputs, return values, permissions, or game decisions.
- Fingerprint the exact B42 target before instrumenting it.
- Fail open on every configuration, fingerprint, or companion failure.

---

## File structure

- `security-server-hook/build.gradle.kts` — agent build and `Premain-Class` manifest.
- `security-server-hook/src/main/java/com/jimsparadise/security/hook/Agent.java` — safe `premain` bootstrap.
- `security-server-hook/src/main/java/com/jimsparadise/security/hook/BuildFingerprint.java` — class-hash compatibility gate.
- `security-server-hook/src/main/java/com/jimsparadise/security/hook/ObservationPublisher.java` — bounded loopback sender.
- `security-server-hook/src/main/java/com/jimsparadise/security/hook/ServerLifecycleAdvice.java` — passive after-return advice.
- `security-server-hook/src/test/java/com/jimsparadise/security/hook/*Test.java` — gate, queue, and advice tests.

### Task 1: Guarded Java agent bootstrap

**Files:**
- Create: `security-server-hook/settings.gradle.kts`
- Create: `security-server-hook/build.gradle.kts`
- Create: `security-server-hook/src/main/java/com/jimsparadise/security/hook/Agent.java`
- Create: `security-server-hook/src/main/java/com/jimsparadise/security/hook/BuildFingerprint.java`
- Create: `security-server-hook/config.example.json`
- Test: `security-server-hook/src/test/java/com/jimsparadise/security/hook/AgentTest.java`

**Interfaces:**
- Produces `public static void Agent.premain(String args, Instrumentation inst)` and `BuildFingerprint.verify(): VerificationResult`.

- [ ] **Step 1: Write failing tests**

```java
@Test void disabledConfigNeverRegistersTransformer() {
  Agent.premain("config=disabled.json", instrumentation);
  verify(instrumentation, never()).addTransformer(any());
}
@Test void unknownBuildNeverRegistersTransformer() {
  when(fingerprint.verify()).thenReturn(VerificationResult.unsupported("hash mismatch"));
  bootstrap.start(instrumentation);
  verify(instrumentation, never()).addTransformer(any());
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew test --tests '*AgentTest'`

Expected: FAIL because agent classes do not exist.

- [ ] **Step 3: Write minimal implementation**

Set `Premain-Class` in the JAR manifest. Default `enabled` to false. Parse only a local config path, calculate SHA-256 for the fixed B42 target class, compare to an allowlisted fingerprint, and catch every bootstrap exception. Emit one structured disabled log and return without adding a transformer on any failure.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew test --tests '*AgentTest'`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add security-server-hook
git commit -m "feat: add guarded server hook bootstrap"
```

### Task 2: Bounded passive observation publisher

**Files:**
- Create: `security-server-hook/src/main/java/com/jimsparadise/security/hook/Observation.java`
- Create: `security-server-hook/src/main/java/com/jimsparadise/security/hook/ObservationPublisher.java`
- Test: `security-server-hook/src/test/java/com/jimsparadise/security/hook/ObservationPublisherTest.java`

**Interfaces:**
- Produces `ObservationPublisher.publish(Observation observation): void`.

- [ ] **Step 1: Write failing tests**

```java
@Test void rejectsNonLoopbackCompanionUrl() {
  assertThrows(IllegalArgumentException.class,
    () -> new ObservationPublisher(URI.create("http://10.0.0.2:8080"), token));
}
@Test void overloadDoesNotBlockServerThread() {
  assertTimeout(Duration.ofMillis(10), () -> publisher.publish(observation));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew test --tests '*ObservationPublisherTest'`

Expected: FAIL because the publisher does not exist.

- [ ] **Step 3: Write minimal implementation**

Accept only `127.0.0.1` or `::1`; publish from a bounded queue with a daemon worker; attach the companion bearer token. On overflow or outage drop and count the event rather than blocking a PZ server thread. Include only type, timestamp, Steam ID when available, and numeric counters.

- [ ] **Step 4: Run tests to verify they pass**

Run: `./gradlew test --tests '*ObservationPublisherTest'`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add security-server-hook
git commit -m "feat: add bounded server observations"
```

### Task 3: One fingerprinted server lifecycle surface

**Files:**
- Create: `security-server-hook/src/main/java/com/jimsparadise/security/hook/ServerLifecycleAdvice.java`
- Create: `security-server-hook/src/test/java/com/jimsparadise/security/hook/ServerLifecycleAdviceTest.java`
- Modify: `42.20/README.md`

**Interfaces:**
- Consumes `ObservationPublisher`.
- Produces a Byte Buddy transformer that invokes `publish` after an allowlisted dedicated-server connection lifecycle method returns.

- [ ] **Step 1: Write failing test**

```java
@Test void adviceOnlyPublishesConnectionObservation() {
  advice.afterConnection("76561198000000000");
  verify(publisher).publish(argThat(o -> o.type().equals("SERVER_CONNECTION")));
  verifyNoMoreInteractions(gameServerMock);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `./gradlew test --tests '*ServerLifecycleAdviceTest'`

Expected: FAIL because the advice class is absent.

- [ ] **Step 3: Write minimal implementation**

Instrument only one named, fingerprinted B42 server connection lifecycle method. Advice runs after original execution, swallows all exceptions, and neither alters arguments nor return values. Document a staging launch command, companion audit-log verification, and rollback by removing `-javaagent`; do not deploy it to production before staging passes.

- [ ] **Step 4: Build and verify**

Run: `./gradlew test shadowJar`

Expected: PASS and a JAR whose manifest includes `Premain-Class`.

- [ ] **Step 5: Commit**

```powershell
git add security-server-hook 42.20/README.md
git commit -m "feat: add staged passive server lifecycle hook"
```

