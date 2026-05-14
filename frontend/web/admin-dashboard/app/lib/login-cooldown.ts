export type LoginCooldownPolicy = {
  maxFailures: number;
  cooldownMs: number;
};

type LoginCooldownRecord = {
  failedCount: number;
  cooldownUntilEpochMs: number;
};

export const DEFAULT_LOGIN_COOLDOWN_POLICY: LoginCooldownPolicy = {
  maxFailures: 3,
  cooldownMs: 60_000,
};

const STORAGE_PREFIX = "ayu:login-cooldown:";
const IDENTIFIER_PREFIX = "ayu:login-cooldown-identifier:";
const EMPTY_RECORD: LoginCooldownRecord = {
  failedCount: 0,
  cooldownUntilEpochMs: 0,
};

function nowMs(): number {
  return Date.now();
}

function normalizeIdentifier(identifier: string): string {
  const normalized = identifier.trim().toLowerCase();
  return normalized || "anonymous";
}

function normalizeRecord(input: unknown): LoginCooldownRecord {
  if (!input || typeof input !== "object") {
    return { ...EMPTY_RECORD };
  }

  const record = input as Partial<LoginCooldownRecord>;
  const failedCount = Number.isFinite(record.failedCount)
    ? Math.max(0, Number(record.failedCount))
    : 0;
  const cooldownUntilEpochMs = Number.isFinite(record.cooldownUntilEpochMs)
    ? Math.max(0, Number(record.cooldownUntilEpochMs))
    : 0;

  return { failedCount, cooldownUntilEpochMs };
}

function canUseStorage(): boolean {
  return typeof window !== "undefined" && typeof window.localStorage !== "undefined";
}

function readString(storageKey: string): string | null {
  if (!canUseStorage()) return null;
  try {
    return window.localStorage.getItem(storageKey);
  } catch {
    return null;
  }
}

function writeString(storageKey: string, value: string): void {
  if (!canUseStorage()) return;
  window.localStorage.setItem(storageKey, value);
}

function readRecord(storageKey: string): LoginCooldownRecord {
  if (!canUseStorage()) return { ...EMPTY_RECORD };
  try {
    const rawValue = window.localStorage.getItem(storageKey);
    if (!rawValue) return { ...EMPTY_RECORD };
    return normalizeRecord(JSON.parse(rawValue));
  } catch {
    return { ...EMPTY_RECORD };
  }
}

function writeRecord(storageKey: string, record: LoginCooldownRecord): void {
  if (!canUseStorage()) return;
  window.localStorage.setItem(storageKey, JSON.stringify(record));
}

export function createLoginCooldownKey(scope: string, identifier: string): string {
  const normalizedScope = scope.trim().toLowerCase() || "default";
  return `${STORAGE_PREFIX}${normalizedScope}:${normalizeIdentifier(identifier)}`;
}

export function getPersistedLoginCooldownIdentifier(scope: string): string | null {
  const normalizedScope = scope.trim().toLowerCase() || "default";
  return readString(`${IDENTIFIER_PREFIX}${normalizedScope}`);
}

export function setPersistedLoginCooldownIdentifier(scope: string, identifier: string): void {
  const normalizedScope = scope.trim().toLowerCase() || "default";
  writeString(`${IDENTIFIER_PREFIX}${normalizedScope}`, normalizeIdentifier(identifier));
}

export function getLoginCooldownRemainingMs(storageKey: string): number {
  const record = readRecord(storageKey);
  return Math.max(0, record.cooldownUntilEpochMs - nowMs());
}

export function canAttemptLogin(storageKey: string): {
  allowed: boolean;
  remainingMs: number;
} {
  const remainingMs = getLoginCooldownRemainingMs(storageKey);
  return { allowed: remainingMs <= 0, remainingMs };
}

export function registerSuccessfulLoginAttempt(storageKey: string): void {
  writeRecord(storageKey, { ...EMPTY_RECORD });
}

export function registerFailedLoginAttempt(
  storageKey: string,
  policy: LoginCooldownPolicy = DEFAULT_LOGIN_COOLDOWN_POLICY,
): {
  failedCount: number;
  isCoolingDown: boolean;
  remainingMs: number;
} {
  const record = readRecord(storageKey);
  const activeCooldownMs = Math.max(0, record.cooldownUntilEpochMs - nowMs());

  if (activeCooldownMs > 0) {
    return {
      failedCount: record.failedCount,
      isCoolingDown: true,
      remainingMs: activeCooldownMs,
    };
  }

  const nextFailedCount = record.failedCount + 1;
  if (nextFailedCount >= policy.maxFailures) {
    const nextRecord: LoginCooldownRecord = {
      failedCount: 0,
      cooldownUntilEpochMs: nowMs() + policy.cooldownMs,
    };
    writeRecord(storageKey, nextRecord);
    return {
      failedCount: nextFailedCount,
      isCoolingDown: true,
      remainingMs: policy.cooldownMs,
    };
  }

  writeRecord(storageKey, { failedCount: nextFailedCount, cooldownUntilEpochMs: 0 });
  return { failedCount: nextFailedCount, isCoolingDown: false, remainingMs: 0 };
}
